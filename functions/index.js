"use strict";

const admin = require("firebase-admin");
const {getFirestore} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {
  onDocumentDeleted,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {GoogleAuth} = require("google-auth-library");
const {Webhook} = require("svix");

const {
  buildAndroidSleepMessage,
  buildIosFallbackSleepMessage,
  buildIosLiveActivityMessage,
  isOngoingSleep,
  liveSleepState,
  shouldProcessSleepWrite,
  shouldRetryRemoteStart,
} = require("./lib/sleepLiveActivity");
const {
  clearInvalidTokenIfCurrent,
  invalidTokenTarget,
} = require("./lib/tokenCleanup");
const {
  applySuperwallEntitlementEvent,
  cleanupDeletedUserEntitlement,
} = require("./lib/superwallEntitlement");

admin.initializeApp();

const db = getFirestore();
const messagingAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});
const superwallWebhookSecret = defineSecret("SUPERWALL_WEBHOOK_SECRET");
const runtimeServiceAccount =
  "babyrelay-functions@babyrelay-ruvix.iam.gserviceaccount.com";

exports.onSuperwallWebhook = onRequest(
  {
    region: "us-central1",
    secrets: [superwallWebhookSecret],
    serviceAccount: runtimeServiceAccount,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method not allowed");
      return;
    }
    const rawBody = request.rawBody && request.rawBody.toString("utf8");
    const headers = {
      "svix-id": request.get("svix-id"),
      "svix-timestamp": request.get("svix-timestamp"),
      "svix-signature": request.get("svix-signature"),
    };
    let event;
    try {
      event = new Webhook(superwallWebhookSecret.value()).verify(
        rawBody || "",
        headers,
      );
    } catch (_) {
      logger.warn("Rejected unverified Superwall webhook");
      response.status(400).send("Webhook verification failed");
      return;
    }

    try {
      const outcome = await applySuperwallEntitlementEvent({
        firestore: db,
        event,
        serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      response.status(200).json({received: true, outcome});
    } catch (error) {
      logger.error("Superwall entitlement webhook failed", {
        message: error instanceof Error ? error.message : "Unknown error",
      });
      response.status(500).send("Webhook processing failed");
    }
  },
);

exports.onUserDeleted = onDocumentDeleted(
  {
    document: "users/{userId}",
    region: "us-central1",
    serviceAccount: runtimeServiceAccount,
  },
  async (event) => {
    const outcome = await cleanupDeletedUserEntitlement({
      firestore: db,
      userId: event.params.userId,
      deletedUser: event.data.data() || {},
      serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info("Cleaned deleted user entitlement", {outcome});
  },
);

exports.onSleepEventWritten = onDocumentWritten(
  {
    document: "families/{familyId}/events/{eventId}",
    region: "us-central1",
    serviceAccount: runtimeServiceAccount,
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
      invalidTokenHandlersForDevice(device),
    );
    return;
  }

  if (device.platform !== "ios") return;
  let endedActivityCount = 0;
  if (endedEventId && (!state || state.eventId !== endedEventId)) {
    endedActivityCount = await endIosActivitiesForDevice(
      device,
      endedEventId,
      nowSeconds,
    );
  }
  if (!state) {
    if (endedActivityCount === 0) {
      endedActivityCount = await endIosActivitiesForDevice(
        device,
        endedEventId,
        nowSeconds,
      );
    }
    if (endedActivityCount === 0) {
      await sendIosFallbackNotification(device, null);
    }
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
      {
        onInvalidFcmToken: () => clearDeviceFcmToken(device),
        onInvalidApnsToken: () => clearActivityUpdateToken(
          activityRef,
          activity.updateToken,
        ),
        tokenKind: "activity_update",
      },
    );
    return;
  }
  if (activity &&
      activity.active &&
      activity.remoteStartRequestedAt &&
      !shouldRetryRemoteStart(activity)) {
    return;
  }

  if (!device.activityKitPushToStartToken) {
    await sendIosFallbackNotification(device, state);
    return;
  }
  const startSent = await sendFcmMessage(
    buildIosLiveActivityMessage({
      fcmToken: device.fcmToken,
      liveActivityToken: device.activityKitPushToStartToken,
      event: "start",
      state,
      nowSeconds,
    }),
    {
      onInvalidFcmToken: () => clearDeviceFcmToken(device),
      onInvalidApnsToken: () => clearPushToStartToken(device),
      tokenKind: "activity_push_to_start",
    },
  );
  if (!startSent) return;
  await activityRef.set({
    id: state.eventId,
    eventId: state.eventId,
    familyId: device.familyId,
    userId: device.userId,
    deviceId: device.id,
    active: true,
    remoteStartAttemptCount:
      Number((activity && activity.remoteStartAttemptCount) || 0) + 1,
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
    if (activity.updateToken) {
      updates.push(sendFcmMessage(
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
        {
          onInvalidFcmToken: () => clearDeviceFcmToken(device),
          onInvalidApnsToken: () => clearActivityUpdateToken(
            doc.ref,
            activity.updateToken,
          ),
          tokenKind: "activity_end",
        },
      ));
    }
    updates.push(doc.ref.set({
      active: false,
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true}));
  }
  await Promise.all(updates);
  return snapshot.docs.filter((doc) => Boolean(doc.data().updateToken)).length;
}

async function sendIosFallbackNotification(device, state) {
  await sendFcmMessage(
    buildIosFallbackSleepMessage({
      fcmToken: device.fcmToken,
      state,
    }),
    invalidTokenHandlersForDevice(device),
  );
}

function invalidTokenHandlersForDevice(device) {
  return {
    onInvalidFcmToken: () => clearDeviceFcmToken(device),
    tokenKind: "fcm_registration",
  };
}

async function clearDeviceFcmToken(device) {
  return clearInvalidTokenIfCurrent({
    firestore: db,
    ref: device.ref,
    field: "fcmToken",
    sentToken: device.fcmToken,
    deactivate: true,
    deleteValue: admin.firestore.FieldValue.delete(),
    serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function clearPushToStartToken(device) {
  return clearInvalidTokenIfCurrent({
    firestore: db,
    ref: device.ref,
    field: "activityKitPushToStartToken",
    sentToken: device.activityKitPushToStartToken,
    deactivate: false,
    deleteValue: admin.firestore.FieldValue.delete(),
    serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function clearActivityUpdateToken(activityRef, token) {
  return clearInvalidTokenIfCurrent({
    firestore: db,
    ref: activityRef,
    field: "updateToken",
    sentToken: token,
    deactivate: true,
    deleteValue: admin.firestore.FieldValue.delete(),
    serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendFcmMessage(message, handlers = {}) {
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
    return true;
  } catch (error) {
    const code = error && error.response && error.response.status;
    if (code === 404 || code === 410) {
      const target = invalidTokenTarget(error, message);
      const cleanup = target === "apns"
        ? handlers.onInvalidApnsToken
        : handlers.onInvalidFcmToken;
      const removed = cleanup ? await cleanup() : false;
      logger.info("Invalid sleep push token handled", {
        code,
        removed,
        tokenKind: handlers.tokenKind || target,
      });
      return false;
    } else {
      throw error;
    }
  }
}
