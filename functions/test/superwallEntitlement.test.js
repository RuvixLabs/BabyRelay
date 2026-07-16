"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  entitlementDecision,
  eventDocumentId,
  familyEntitlementFromRows,
  validateSuperwallEvent,
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
