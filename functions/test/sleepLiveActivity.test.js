"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  REMOTE_SLEEP_TYPE_KEY,
  REMOTE_SLEEP_UPDATE_TYPE,
  activeSleepSummary,
  buildAndroidSleepMessage,
  buildIosLiveActivityMessage,
  liveSleepState,
  shouldProcessSleepWrite,
} = require("../lib/sleepLiveActivity");

test("builds multi-child active sleep summary in start order", () => {
  const children = new Map([
    ["mae", {nickname: "Mae"}],
    ["theo", {nickname: "Theo"}],
  ]);
  assert.equal(
    activeSleepSummary(children, [
      {id: "s1", childId: "mae", type: "sleep", startAtMillis: 100},
      {id: "s2", childId: "theo", type: "sleep", startAtMillis: 200},
    ]),
    "Mae + Theo sleeping",
  );
});

test("liveSleepState picks the oldest ongoing sleep as the family surface", () => {
  const state = liveSleepState({
    childrenById: new Map([
      ["mae", {nickname: "Mae"}],
      ["theo", {nickname: "Theo"}],
    ]),
    sleeps: [
      {
        id: "later",
        childId: "theo",
        type: "sleep",
        startAtMillis: 200,
        endAt: null,
      },
      {
        id: "first",
        childId: "mae",
        type: "sleep",
        startAtMillis: 100,
        endAt: null,
      },
    ],
  });

  assert.deepEqual(state, {
    eventId: "first",
    childName: "Mae",
    startedAtMillis: 100,
    activeSleepCount: 2,
    activeSleepSummary: "Mae + Theo sleeping",
  });
});

test("iOS remote start payload uses FCM live_activity_token and ActivityKit aps keys", () => {
  const message = buildIosLiveActivityMessage({
    fcmToken: "fcm",
    liveActivityToken: "push-to-start",
    event: "start",
    nowSeconds: 123,
    state: {
      eventId: "sleep_1",
      childName: "Mae",
      startedAtMillis: 456000,
      activeSleepCount: 1,
      activeSleepSummary: "Mae sleeping",
    },
  });

  assert.equal(message.token, "fcm");
  assert.equal(message.apns.live_activity_token, "push-to-start");
  assert.equal(message.apns.payload.aps.event, "start");
  assert.equal(
    message.apns.payload.aps["attributes-type"],
    "BabyRelaySleepAttributes",
  );
  assert.deepEqual(message.apns.payload.aps.attributes, {
    eventId: "sleep_1",
    childName: "Mae",
  });
  assert.deepEqual(message.apns.payload.aps["content-state"], {
    childName: "Mae",
    startedAtMillis: 456000,
    activeSleepCount: 1,
    activeSleepSummary: "Mae sleeping",
  });
});

test("Android remote message carries only string data payload values", () => {
  const message = buildAndroidSleepMessage({
    fcmToken: "android-fcm",
    state: {
      eventId: "sleep_1",
      childName: "Mae",
      startedAtMillis: 456000,
      activeSleepCount: 2,
      activeSleepSummary: "Mae + Theo sleeping",
    },
  });

  assert.equal(message.token, "android-fcm");
  assert.equal(message.data[REMOTE_SLEEP_TYPE_KEY], REMOTE_SLEEP_UPDATE_TYPE);
  for (const value of Object.values(message.data)) {
    assert.equal(typeof value, "string");
  }
});

test("sleep writes are the only trigger-worthy event writes", () => {
  assert.equal(shouldProcessSleepWrite(null, {type: "sleep"}), true);
  assert.equal(shouldProcessSleepWrite({type: "sleep"}, {type: "sleep"}), true);
  assert.equal(shouldProcessSleepWrite({type: "sleep"}, null), true);
  assert.equal(shouldProcessSleepWrite(null, {type: "feed"}), false);
});
