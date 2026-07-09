"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  REMOTE_SLEEP_TYPE_KEY,
  REMOTE_SLEEP_END_TYPE,
  REMOTE_SLEEP_UPDATE_TYPE,
  activeSleepSummary,
  buildAndroidSleepMessage,
  buildIosFallbackSleepMessage,
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

test("iOS Live Activity update and end payloads keep the expected event shape", () => {
  const state = {
    eventId: "sleep_1",
    childName: "Mae",
    startedAtMillis: 456000,
    activeSleepCount: 1,
    activeSleepSummary: "Mae sleeping",
  };
  const update = buildIosLiveActivityMessage({
    fcmToken: "fcm",
    liveActivityToken: "update-token",
    event: "update",
    nowSeconds: 123,
    state,
  });
  const end = buildIosLiveActivityMessage({
    fcmToken: "fcm",
    liveActivityToken: "update-token",
    event: "end",
    nowSeconds: 124,
    state,
  });

  assert.equal(update.apns.payload.aps.event, "update");
  assert.equal(update.apns.headers["apns-priority"], "5");
  assert.equal(update.apns.payload.aps.attributes, undefined);
  assert.equal(end.apns.payload.aps.event, "end");
  assert.equal(end.apns.payload.aps["dismissal-date"], 124);
});

test("iOS fallback sends high-priority start and end caregiver alerts", () => {
  const update = buildIosFallbackSleepMessage({
    fcmToken: "ios-fcm",
    state: {
      eventId: "sleep_1",
      childName: "Mae",
      startedAtMillis: 456000,
      activeSleepCount: 1,
      activeSleepSummary: "Mae sleeping",
    },
  });
  const end = buildIosFallbackSleepMessage({
    fcmToken: "ios-fcm",
    state: null,
  });

  assert.equal(update.apns.headers["apns-priority"], "10");
  assert.equal(update.apns.payload.aps.alert.title, "Mae is sleeping");
  assert.equal(update.data[REMOTE_SLEEP_TYPE_KEY], REMOTE_SLEEP_UPDATE_TYPE);
  assert.equal(end.apns.payload.aps.alert.title, "Sleep ended");
  assert.equal(end.data[REMOTE_SLEEP_TYPE_KEY], REMOTE_SLEEP_END_TYPE);
  for (const value of Object.values(update.data)) {
    assert.equal(typeof value, "string");
  }
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
