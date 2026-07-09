"use strict";

const LIVE_ACTIVITY_ATTRIBUTES_TYPE = "BabyRelaySleepAttributes";
const REMOTE_SLEEP_TYPE_KEY = "babyrelayType";
const REMOTE_SLEEP_UPDATE_TYPE = "sleep_live_update";
const REMOTE_SLEEP_END_TYPE = "sleep_live_end";

function isOngoingSleep(event) {
  return Boolean(event && event.type === "sleep" && !event.endAt);
}

function ongoingSleeps(events) {
  return events
    .filter(isOngoingSleep)
    .sort((a, b) => startMillis(a) - startMillis(b));
}

function startMillis(event) {
  if (Number.isFinite(event.startAtMillis)) return event.startAtMillis;
  const parsed = Date.parse(event.startAt || "");
  return Number.isFinite(parsed) ? parsed : Date.now();
}

function activeSleepSummary(childrenById, sleeps) {
  const names = [];
  const seen = new Set();
  for (const sleep of sleeps) {
    if (seen.has(sleep.childId)) continue;
    seen.add(sleep.childId);
    const child = childrenById.get(sleep.childId);
    if (child && child.nickname) names.push(child.nickname);
  }
  if (names.length === 0) return "Sleep timer running";
  if (names.length === 1) return `${names[0]} sleeping`;
  if (names.length === 2) return `${names[0]} + ${names[1]} sleeping`;
  return `${names[0]} + ${names.length - 1} more sleeping`;
}

function liveSleepState({childrenById, sleeps}) {
  const active = ongoingSleeps(sleeps);
  if (active.length === 0) return null;
  const primary = active[0];
  const child = childrenById.get(primary.childId) || {};
  const childName = child.nickname || "Baby";
  return {
    eventId: primary.id,
    childName,
    startedAtMillis: startMillis(primary),
    activeSleepCount: active.length,
    activeSleepSummary: activeSleepSummary(childrenById, active),
  };
}

function liveActivityContentState(state) {
  return {
    childName: state.childName,
    startedAtMillis: state.startedAtMillis,
    activeSleepCount: state.activeSleepCount,
    activeSleepSummary: state.activeSleepSummary,
  };
}

function buildIosLiveActivityMessage({
  fcmToken,
  liveActivityToken,
  event,
  state,
  nowSeconds,
}) {
  const aps = {
    timestamp: nowSeconds,
    event,
    "content-state": liveActivityContentState(state),
  };

  if (event === "start") {
    aps["attributes-type"] = LIVE_ACTIVITY_ATTRIBUTES_TYPE;
    aps.attributes = {
      eventId: state.eventId,
      childName: state.childName,
    };
    aps.alert = {
      title: state.activeSleepCount > 1
        ? `${state.activeSleepCount} children sleeping`
        : `${state.childName} is sleeping`,
      body: state.activeSleepSummary,
    };
  } else if (event === "update") {
    aps.alert = {
      title: state.activeSleepCount > 1
        ? `${state.activeSleepCount} sleep timers running`
        : `${state.childName} is sleeping`,
      body: state.activeSleepSummary,
    };
  } else if (event === "end") {
    aps["dismissal-date"] = nowSeconds;
  }

  return {
    token: fcmToken,
    apns: {
      live_activity_token: liveActivityToken,
      headers: {
        "apns-priority": event === "start" ? "10" : "5",
      },
      payload: {aps},
    },
  };
}

function buildAndroidSleepMessage({fcmToken, state}) {
  const ending = state == null;
  const data = {
    [REMOTE_SLEEP_TYPE_KEY]: ending
      ? REMOTE_SLEEP_END_TYPE
      : REMOTE_SLEEP_UPDATE_TYPE,
  };
  if (state) {
    Object.assign(data, {
      eventId: state.eventId,
      childName: state.childName,
      startedAtMillis: String(state.startedAtMillis),
      activeSleepCount: String(state.activeSleepCount),
      activeSleepSummary: state.activeSleepSummary,
    });
  }
  return {
    token: fcmToken,
    data,
    android: {
      priority: "high",
    },
  };
}

function buildIosFallbackSleepMessage({fcmToken, state}) {
  const ending = state == null;
  const title = ending
    ? "Sleep ended"
    : state.activeSleepCount > 1
      ? `${state.activeSleepCount} children sleeping`
      : `${state.childName} is sleeping`;
  const body = ending ? "The shared sleep timer has ended." : state.activeSleepSummary;
  const data = {
    [REMOTE_SLEEP_TYPE_KEY]: ending
      ? REMOTE_SLEEP_END_TYPE
      : REMOTE_SLEEP_UPDATE_TYPE,
  };
  if (state) {
    Object.assign(data, {
      eventId: state.eventId,
      childName: state.childName,
      startedAtMillis: String(state.startedAtMillis),
      activeSleepCount: String(state.activeSleepCount),
      activeSleepSummary: state.activeSleepSummary,
    });
  }
  return {
    token: fcmToken,
    data,
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          alert: {title, body},
          sound: "default",
          "content-available": 1,
        },
      },
    },
  };
}

function shouldProcessSleepWrite(before, after) {
  return (before && before.type === "sleep") || (after && after.type === "sleep");
}

module.exports = {
  LIVE_ACTIVITY_ATTRIBUTES_TYPE,
  REMOTE_SLEEP_TYPE_KEY,
  REMOTE_SLEEP_UPDATE_TYPE,
  REMOTE_SLEEP_END_TYPE,
  activeSleepSummary,
  buildAndroidSleepMessage,
  buildIosFallbackSleepMessage,
  buildIosLiveActivityMessage,
  isOngoingSleep,
  liveSleepState,
  ongoingSleeps,
  shouldProcessSleepWrite,
  startMillis,
};
