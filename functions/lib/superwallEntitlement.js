"use strict";

const crypto = require("node:crypto");

const SUPERWALL_PROJECT_ID = 26262;
const SUPERWALL_APPLICATION_IDS = new Set([49825, 49826]);
const BABYRELAY_BUNDLE_ID = "com.ruvixlabs.babyrelay";
const PRODUCT_IDS = new Set([
  "babyrelay_pro_monthly",
  "babyrelay_pro_annual",
  "babyrelay_pro_special_annual",
]);

const ACTIVE_EVENTS = new Set([
  "initial_purchase",
  "renewal",
  "uncancellation",
  "product_change",
  "non_renewing_purchase",
]);
const INACTIVE_EVENTS = new Set(["expiration", "subscription_paused"]);

function validateSuperwallEvent(event) {
  if (!event || event.object !== "event" || typeof event.data !== "object") {
    throw new Error("Invalid Superwall event envelope");
  }
  if (event.projectId !== SUPERWALL_PROJECT_ID) {
    throw new Error("Unexpected Superwall project");
  }
  if (!SUPERWALL_APPLICATION_IDS.has(event.applicationId)) {
    throw new Error("Unexpected Superwall application");
  }
  if (event.data.bundleId !== BABYRELAY_BUNDLE_ID) {
    throw new Error("Unexpected app bundle");
  }
  if (!PRODUCT_IDS.has(event.data.productId)) {
    throw new Error("Unexpected subscription product");
  }
  const userId = event.data.originalAppUserId;
  if (!isFirebaseUserId(userId)) {
    throw new Error("Webhook is missing a Firebase app user id");
  }
  if (typeof event.data.id !== "string" || event.data.id.length === 0) {
    throw new Error("Webhook is missing an event id");
  }
  return event;
}

function isFirebaseUserId(value) {
  return typeof value === "string" &&
    value.length >= 6 &&
    value.length <= 128 &&
    /^[A-Za-z0-9_-]+$/.test(value) &&
    !value.startsWith("$SuperwallAlias");
}

function entitlementDecision(event) {
  const price = Number(event.data.price || 0);
  if (price < 0) return false;
  if (ACTIVE_EVENTS.has(event.type)) return true;
  if (INACTIVE_EVENTS.has(event.type)) return false;
  // Cancellation and billing issues do not end access immediately. The store
  // remains authoritative until Superwall sends expiration/pause/refund.
  return null;
}

function eventTimestampMillis(event) {
  const candidates = [event.data.ts, event.timestamp, event.data.purchasedAt];
  for (const value of candidates) {
    if (Number.isFinite(value) && value > 0) return Math.trunc(value);
  }
  return Date.now();
}

function eventDocumentId(event) {
  return crypto
    .createHash("sha256")
    .update(`${event.projectId}:${event.applicationId}:${event.data.id}`)
    .digest("hex");
}

function familyEntitlementFromRows(rows) {
  const active = rows
    .filter((row) => row && row.active === true)
    .sort((a, b) =>
      Number(b.sourceTimestampMillis || 0) -
      Number(a.sourceTimestampMillis || 0));
  const winner = active[0];
  return {
    active: Boolean(winner),
    planId: winner && typeof winner.productId === "string"
      ? winner.productId
      : "",
    ownerId: winner && typeof winner.userId === "string"
      ? winner.userId
      : "",
  };
}

async function applySuperwallEntitlementEvent({
  firestore,
  event,
  serverTimestamp,
}) {
  validateSuperwallEvent(event);
  const decision = entitlementDecision(event);
  const timestampMillis = eventTimestampMillis(event);
  const userId = event.data.originalAppUserId;
  const eventRef = firestore.collection("superwallWebhookEvents")
    .doc(eventDocumentId(event));
  const userRef = firestore.doc(`users/${userId}`);

  return firestore.runTransaction(async (transaction) => {
    const existingEvent = await transaction.get(eventRef);
    if (existingEvent.exists) return "duplicate";

    const userSnapshot = await transaction.get(userRef);
    const familyId = userSnapshot.exists
      ? userSnapshot.data().currentFamilyId
      : null;
    if (typeof familyId !== "string" || familyId.length === 0) {
      transaction.create(eventRef, webhookReceipt({
        event,
        userId,
        familyId: "",
        outcome: "unmatched_user",
        serverTimestamp,
      }));
      return "unmatched_user";
    }

    const familyRef = firestore.doc(`families/${familyId}`);
    const familySnapshot = await transaction.get(familyRef);
    if (!familySnapshot.exists) {
      transaction.create(eventRef, webhookReceipt({
        event,
        userId,
        familyId,
        outcome: "missing_family",
        serverTimestamp,
      }));
      return "missing_family";
    }
    const family = familySnapshot.data();
    const memberIds = Array.isArray(family.memberIds) ? family.memberIds : [];
    if (!memberIds.includes(userId)) {
      transaction.create(eventRef, webhookReceipt({
        event,
        userId,
        familyId,
        outcome: "not_family_member",
        serverTimestamp,
      }));
      return "not_family_member";
    }

    if (decision === null) {
      transaction.create(eventRef, webhookReceipt({
        event,
        userId,
        familyId,
        outcome: "acknowledged_no_access_change",
        serverTimestamp,
      }));
      return "acknowledged_no_access_change";
    }

    const entitlementRefs = memberIds.map((memberId) =>
      firestore.doc(`users/${memberId}/entitlements/pro`));
    const entitlementSnapshots = [];
    for (const ref of entitlementRefs) {
      entitlementSnapshots.push(await transaction.get(ref));
    }
    const currentIndex = memberIds.indexOf(userId);
    const currentSnapshot = entitlementSnapshots[currentIndex];
    const current = currentSnapshot.exists ? currentSnapshot.data() : null;
    if (current &&
        Number(current.sourceTimestampMillis || 0) > timestampMillis) {
      transaction.create(eventRef, webhookReceipt({
        event,
        userId,
        familyId,
        outcome: "stale_ignored",
        serverTimestamp,
      }));
      return "stale_ignored";
    }

    const entitlement = {
      active: decision,
      userId,
      familyId,
      productId: event.data.productId,
      store: event.data.store || "",
      environment: event.data.environment || "",
      expirationAt: Number.isFinite(event.data.expirationAt)
        ? event.data.expirationAt
        : null,
      sourceEventId: event.data.id,
      sourceTimestampMillis: timestampMillis,
      updatedAt: serverTimestamp,
    };
    transaction.set(entitlementRefs[currentIndex], entitlement, {merge: true});

    const rows = entitlementSnapshots.map((snapshot, index) => {
      if (index === currentIndex) return entitlement;
      return snapshot.exists ? snapshot.data() : null;
    });
    const aggregate = familyEntitlementFromRows(rows);
    transaction.update(familyRef, {
      familySubscriptionActive: aggregate.active,
      familySubscriptionPlanId: aggregate.planId,
      familySubscriptionOwnerId: aggregate.ownerId,
      familySubscriptionUpdatedAtMillis: timestampMillis,
      familySubscriptionUpdatedAt: serverTimestamp,
    });
    transaction.create(eventRef, webhookReceipt({
      event,
      userId,
      familyId,
      outcome: aggregate.active ? "family_active" : "family_inactive",
      serverTimestamp,
    }));
    return aggregate.active ? "family_active" : "family_inactive";
  });
}

function webhookReceipt({
  event,
  userId,
  familyId,
  outcome,
  serverTimestamp,
}) {
  return {
    id: event.data.id,
    type: event.type,
    projectId: event.projectId,
    applicationId: event.applicationId,
    userId,
    familyId,
    environment: event.data.environment || "",
    outcome,
    receivedAt: serverTimestamp,
  };
}

module.exports = {
  BABYRELAY_BUNDLE_ID,
  PRODUCT_IDS,
  SUPERWALL_APPLICATION_IDS,
  SUPERWALL_PROJECT_ID,
  applySuperwallEntitlementEvent,
  entitlementDecision,
  eventDocumentId,
  eventTimestampMillis,
  familyEntitlementFromRows,
  isFirebaseUserId,
  validateSuperwallEvent,
};
