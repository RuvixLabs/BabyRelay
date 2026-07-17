"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  cleanupDeletedUserEntitlement,
  entitlementDecision,
  eventDocumentId,
  familyEntitlementFromRows,
  validateSuperwallEvent,
  webhookReceipt,
} = require("../lib/superwallEntitlement");

function event(type, overrides = {}) {
  return {
    object: "event",
    type,
    projectId: 26262,
    applicationId: 49825,
    timestamp: 1000,
    data: {
      id: `transaction:${type}`,
      originalAppUserId: "firebase_uid_123",
      bundleId: "com.ruvixlabs.babyrelay",
      productId: "babyrelay_pro_monthly",
      price: 9.99,
      ...overrides,
    },
  };
}

test("accepts only the BabyRelay project, apps, products, and Firebase user", () => {
  assert.equal(validateSuperwallEvent(event("initial_purchase")).type,
    "initial_purchase");
  assert.throws(() => validateSuperwallEvent({
    ...event("initial_purchase"),
    projectId: 999,
  }));
  assert.throws(() => validateSuperwallEvent(event("initial_purchase", {
    originalAppUserId: "$SuperwallAlias:ABC",
  })));
  assert.throws(() => validateSuperwallEvent(event("initial_purchase", {
    productId: "another_app_product",
  })));
});

test("store lifecycle decisions preserve access through cancellation", () => {
  assert.equal(entitlementDecision(event("initial_purchase")), true);
  assert.equal(entitlementDecision(event("renewal")), true);
  assert.equal(entitlementDecision(event("uncancellation")), true);
  assert.equal(entitlementDecision(event("cancellation")), null);
  assert.equal(entitlementDecision(event("billing_issue")), null);
  assert.equal(entitlementDecision(event("expiration")), false);
  assert.equal(entitlementDecision(event("subscription_paused")), false);
  assert.equal(entitlementDecision(event("renewal", {price: -9.99})), false);
});

test("family remains active while any member has a verified entitlement", () => {
  assert.deepEqual(familyEntitlementFromRows([
    {active: false, userId: "one", sourceTimestampMillis: 200},
    {
      active: true,
      userId: "two",
      productId: "babyrelay_pro_annual",
      sourceTimestampMillis: 100,
    },
  ]), {
    active: true,
    ownerId: "two",
    planId: "babyrelay_pro_annual",
  });
  assert.deepEqual(familyEntitlementFromRows([
    {active: false, userId: "one"},
  ]), {active: false, ownerId: "", planId: ""});
});

test("webhook receipt ids are deterministic and Firestore-safe", () => {
  const id = eventDocumentId(event("renewal"));
  assert.match(id, /^[a-f0-9]{64}$/);
  assert.equal(id, eventDocumentId(event("renewal")));
});

test("webhook receipts retain no user or family identifiers", () => {
  const receipt = webhookReceipt({
    event: event("renewal"),
    outcome: "family_active",
    serverTimestamp: "server-time",
  });
  assert.equal(receipt.userId, undefined);
  assert.equal(receipt.familyId, undefined);
  assert.equal(receipt.outcome, "family_active");
});

test("deleted users lose their entitlement and family access is recomputed", async () => {
  const documents = new Map([
    ["users/deleted/entitlements/pro", {
      active: true,
      familyId: "family-1",
      productId: "babyrelay_pro_monthly",
      userId: "deleted",
      sourceTimestampMillis: 200,
    }],
    ["users/remaining/entitlements/pro", {
      active: true,
      familyId: "family-1",
      productId: "babyrelay_pro_annual",
      userId: "remaining",
      sourceTimestampMillis: 100,
    }],
    ["families/family-1", {
      memberIds: ["remaining"],
      familySubscriptionActive: true,
      familySubscriptionOwnerId: "deleted",
      familySubscriptionPlanId: "babyrelay_pro_monthly",
    }],
  ]);
  const firestore = {
    doc(path) {
      return {
        async get() {
          const value = documents.get(path);
          return {exists: value !== undefined, data: () => value};
        },
        async delete() {
          documents.delete(path);
        },
        async update(patch) {
          documents.set(path, {...documents.get(path), ...patch});
        },
      };
    },
  };

  const outcome = await cleanupDeletedUserEntitlement({
    firestore,
    userId: "deleted",
    deletedUser: {currentFamilyId: "family-1"},
    serverTimestamp: "server-time",
    nowMillis: 300,
  });

  assert.equal(outcome, "family_active");
  assert.equal(documents.has("users/deleted/entitlements/pro"), false);
  assert.deepEqual(documents.get("families/family-1"), {
    memberIds: ["remaining"],
    familySubscriptionActive: true,
    familySubscriptionOwnerId: "remaining",
    familySubscriptionPlanId: "babyrelay_pro_annual",
    familySubscriptionUpdatedAtMillis: 300,
    familySubscriptionUpdatedAt: "server-time",
  });
});
