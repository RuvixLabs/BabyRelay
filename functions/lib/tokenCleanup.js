"use strict";

function invalidTokenTarget(error, message) {
  const details = error && error.response && error.response.data &&
    error.response.data.error && error.response.data.error.details;
  if (Array.isArray(details)) {
    for (const detail of details) {
      const type = String(detail && detail["@type"] || "");
      if (type.endsWith("FcmError")) return "fcm";
      if (type.endsWith("ApnsError")) return "apns";
    }
  }
  return message && message.apns && message.apns.live_activity_token
    ? "apns"
    : "fcm";
}

async function clearInvalidTokenIfCurrent({
  firestore,
  ref,
  field,
  sentToken,
  deactivate,
  deleteValue,
  serverTimestamp,
}) {
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return false;
    const data = snapshot.data();
    if (!data || data[field] !== sentToken) return false;

    const patch = {
      [field]: deleteValue,
      updatedAt: serverTimestamp,
    };
    if (deactivate) patch.active = false;
    transaction.set(ref, patch, {merge: true});
    return true;
  });
}

module.exports = {
  clearInvalidTokenIfCurrent,
  invalidTokenTarget,
};
