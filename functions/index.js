"use strict";

const admin = require("firebase-admin");
const {getFirestore} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {GoogleAuth} = require("google-auth-library");

const {
  buildAndroidSleepMessage,
  buildIosLiveActivityMessage,
  isOngoingSleep,
  liveSleepState,
  shouldProcessSleepWrite,
} = require("./lib/sleepLiveActivity");

admin.initializeApp();

const db = getFirestore();
const messagingAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});

exports.onSleepEventWritten = onDocumentWritten(
  {
    document: "families/{familyId}/events/{eventId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!shouldProcessSleepWrite(before, after)) return;

    const {familyId, eventId} = event.params;
    const sourceDeviceId = (after && after.loggedByDeviceId) ||
      (before && before.loggedByDeviceId) ||
      "";

    const [familySnapshot, eventsSnapshot, childrenSnapshot] = await Promise.all([
      db.doc(`families/${familyId}`).get(),
      db.collection(`families/${familyId}/events`)
        .where("type", "==", "sleep")
        .where("endAt", "==", null)
        .get(),
      db.collection(`families/${familyId}/children`).get(),
    ]);

    if (!familySnapshot.exists) return;
    const family = familySnapshot.data();
    const memberIds = Array.isArray(family.memberIds) ? family.memberIds : [];
    if (memberIds.length === 0) return;

    const childrenById = new Map();
    childrenSnapshot.forEach((doc) => childrenById.set(doc.id, doc.data()));
    const sleeps = [];
    eventsSnapshot.forEach((doc) => sleeps.push({...doc.data(), id: doc.id}));
    const state = liveSleepState({childrenById, sleeps});
    const endedEventId = isOngoingSleep(before) && !isOngoingSleep(after)
      ? eventId
      : null;

    const devices = await loadFamilyDevices(memberIds, familyId);
    const nowSeconds = Math.floor(Date.now() / 1000);
    const sends = [];
    for (const device of devices) {
      if (!device.fcmToken || device.id === sourceDeviceId) continue;
      sends.push(
        sendDeviceSleepSurface({
          device,
          state,
          endedEventId,
          nowSeconds,
        }),
      );
    }
    const results = await Promise.allSettled(sends);
    const failures = results.filter((result) => result.status === "rejected");
    if (failures.length > 0) {
      logger.warn("Some sleep live surface fanout sends failed", {
        familyId,
        failedCount: failures.length,
      });
    }
  },
);

async function loadFamilyDevices(memberIds, familyId) {
  const deviceSnapshots = await Promise.all(
    memberIds.map((userId) =>
      db.collection(`users/${userId}/devices`)
        .where("familyId", "==", familyId)
        .where("active", "==", true)
        .get()
        .then((snapshot) => ({userId, snapshot})),
    ),
  );

  const devices = [];
  for (const {userId, snapshot} of deviceSnapshots) {
    snapshot.forEach((doc) => {
      const data = doc.data();
      devices.push({
        ...data,
        userId,
        id: doc.id,
        ref: doc.ref,
      });
    });
  }
  return devices;
}

async function sendDeviceSleepSurface({
  device,
  state,
  endedEventId,
  nowSeconds,
}) {
  if (device.platform === "android") {
    await sendFcmMessage(
      buildAndroidSleepMessage({
        fcmToken: device.fcmToken,
        state,
      }),
    );
    return;
  }

  if (device.platform !== "ios") return;
  if (endedEventId && (!state || state.eventId !== endedEventId)) {
    await endIosActivitiesForDevice(device, endedEventId, nowSeconds);
  }
  if (!state) {
    await endIosActivitiesForDevice(device, endedEventId, nowSeconds);
    return;
  }

  const activityRef = device.ref.collection("activities").doc(state.eventId);
  const activitySnapshot = await activityRef.get();
  const activity = activitySnapshot.exists ? activitySnapshot.data() : null;
  if (activity && activity.active && activity.updateToken) {
    await sendFcmMessage(
      buildIosLiveActivityMessage({
        fcmToken: device.fcmToken,
        liveActivityToken: activity.updateToken,
        event: "update",
        state,
        nowSeconds,
      }),
    );
    return;
  }
  if (activity && activity.active && activity.remoteStartRequestedAt) {
    return;
  }

  if (!device.activityKitPushToStartToken) return;
  await sendFcmMessage(
    buildIosLiveActivityMessage({
      fcmToken: device.fcmToken,
      liveActivityToken: device.activityKitPushToStartToken,
      event: "start",
      state,
      nowSeconds,
    }),
  );
  await activityRef.set({
    id: state.eventId,
    eventId: state.eventId,
    familyId: device.familyId,
    userId: device.userId,
    deviceId: device.id,
    active: true,
    remoteStartRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function endIosActivitiesForDevice(device, endedEventId, nowSeconds) {
  let query = device.ref.collection("activities").where("active", "==", true);
  if (endedEventId) {
    query = query.where("eventId", "==", endedEventId);
  }
  const snapshot = await query.get();
  const updates = [];
  for (const doc of snapshot.docs) {
    const activity = doc.data();
    if (!activity.updateToken) continue;
    updates.push(
      sendFcmMessage(
        buildIosLiveActivityMessage({
          fcmToken: device.fcmToken,
          liveActivityToken: activity.updateToken,
          event: "end",
          state: {
            eventId: activity.eventId || doc.id,
            childName: "BabyRelay",
            startedAtMillis: Date.now(),
            activeSleepCount: 0,
            activeSleepSummary: "Sleep ended",
          },
          nowSeconds,
        }),
      ).then(() => doc.ref.set({
        active: false,
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true})),
    );
  }
  await Promise.all(updates);
}

async function sendFcmMessage(message) {
  try {
    const client = await messagingAuth.getClient();
    const projectId = process.env.GCLOUD_PROJECT ||
      process.env.GCP_PROJECT ||
      await messagingAuth.getProjectId();
    await client.request({
      url: `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      method: "POST",
      data: {message},
    });
  } catch (error) {
    const code = error && error.response && error.response.status;
    if (code === 404 || code === 410) {
      logger.info("Pruning invalid sleep push token", {code});
    } else {
      throw error;
    }
  }
}
