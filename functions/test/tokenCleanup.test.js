"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  clearInvalidTokenIfCurrent,
  invalidTokenTarget,
} = require("../lib/tokenCleanup");

test("invalid token cleanup changes only the exact matching device", async () => {
  const deleted = Symbol("deleted");
  const firestore = new FakeFirestore({
    "users/a/devices/one": {fcmToken: "stale", active: true},
    "users/b/devices/two": {fcmToken: "other", active: true},
  }, deleted);

  const removed = await clearInvalidTokenIfCurrent({
    firestore,
    ref: {path: "users/a/devices/one"},
    field: "fcmToken",
    sentToken: "stale",
    deactivate: true,
    deleteValue: deleted,
    serverTimestamp: "now",
  });

  assert.equal(removed, true);
  assert.deepEqual(firestore.docs.get("users/a/devices/one"), {
    active: false,
    updatedAt: "now",
  });
  assert.deepEqual(firestore.docs.get("users/b/devices/two"), {
    fcmToken: "other",
    active: true,
  });
  assert.deepEqual(firestore.writePaths, ["users/a/devices/one"]);
});

test("invalid token cleanup preserves a token refreshed after the send", async () => {
  const deleted = Symbol("deleted");
  const firestore = new FakeFirestore({
    "users/a/devices/one": {fcmToken: "fresh", active: true},
  }, deleted);

  const removed = await clearInvalidTokenIfCurrent({
    firestore,
    ref: {path: "users/a/devices/one"},
    field: "fcmToken",
    sentToken: "stale",
    deactivate: true,
    deleteValue: deleted,
    serverTimestamp: "now",
  });

  assert.equal(removed, false);
  assert.deepEqual(firestore.docs.get("users/a/devices/one"), {
    fcmToken: "fresh",
    active: true,
  });
  assert.deepEqual(firestore.writePaths, []);
});

test("invalid token target distinguishes FCM registration from APNs tokens", () => {
  const fcmError = {
    response: {
      data: {
        error: {
          details: [{"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError"}],
        },
      },
    },
  };
  const apnsError = {
    response: {
      data: {
        error: {
          details: [{"@type": "type.googleapis.com/google.firebase.fcm.v1.ApnsError"}],
        },
      },
    },
  };

  assert.equal(invalidTokenTarget(fcmError, {}), "fcm");
  assert.equal(invalidTokenTarget(apnsError, {}), "apns");
  assert.equal(
    invalidTokenTarget({}, {apns: {live_activity_token: "activity"}}),
    "apns",
  );
});

class FakeFirestore {
  constructor(initialDocs, deletedValue) {
    this.docs = new Map(Object.entries(initialDocs));
    this.deletedValue = deletedValue;
    this.writePaths = [];
  }

  async runTransaction(action) {
    return action({
      get: async (ref) => ({
        exists: this.docs.has(ref.path),
        data: () => this.docs.get(ref.path),
      }),
      set: (ref, patch) => {
        const next = {...this.docs.get(ref.path)};
        for (const [key, value] of Object.entries(patch)) {
          if (value === this.deletedValue) {
            delete next[key];
          } else {
            next[key] = value;
          }
        }
        this.docs.set(ref.path, next);
        this.writePaths.push(ref.path);
      },
    });
  }
}
