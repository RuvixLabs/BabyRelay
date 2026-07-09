import Flutter
import ActivityKit
import UserNotifications
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var sleepActivity: Any?
  private var sleepActivityTokenChannel: FlutterMethodChannel?
  private var observedActivityIds = Set<String>()
  private var tokenObserverTasks: [Task<Void, Never>] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    configureSleepActivityChannel(messenger: messenger)
    configureSleepActivityTokenChannel(messenger: messenger)
    startObservingSleepActivityTokens()
  }

  private func configureSleepActivityChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.ruvixlabs.babyrelay/sleep_activity",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startOrUpdate":
        self?.handleStartOrUpdateSleepActivity(call.arguments)
        result(nil)
      case "end":
        self?.endSleepActivity()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureSleepActivityTokenChannel(messenger: FlutterBinaryMessenger) {
    sleepActivityTokenChannel = FlutterMethodChannel(
      name: "com.ruvixlabs.babyrelay/sleep_activity_tokens",
      binaryMessenger: messenger
    )
  }

  private func handleStartOrUpdateSleepActivity(_ arguments: Any?) {
    guard #available(iOS 16.2, *),
      let payload = arguments as? [String: Any],
      let eventId = payload["eventId"] as? String,
      let childName = payload["childName"] as? String,
      let startedAtMillis = millisValue(payload["startedAtMillis"])
    else {
      return
    }
    let activeSleepCount = payload["activeSleepCount"] as? Int ?? 1
    let activeSleepSummary = payload["activeSleepSummary"] as? String ?? "\(childName) is sleeping"
    let state = BabyRelaySleepAttributes.ContentState(
      childName: childName,
      startedAtMillis: startedAtMillis,
      activeSleepCount: activeSleepCount,
      activeSleepSummary: activeSleepSummary
    )

    if let activity = existingSleepActivity(eventId: eventId) {
      sleepActivity = activity
      observeSleepActivity(activity)
      Task {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      }
      return
    }

    endSleepActivities(except: eventId)
    let attributes = BabyRelaySleepAttributes(eventId: eventId, childName: childName)
    do {
      sleepActivity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: nil),
        pushType: .token
      )
      if let activity = sleepActivity as? Activity<BabyRelaySleepAttributes> {
        observeSleepActivity(activity)
      }
    } catch {
      sleepActivity = nil
    }
  }

  private func millisValue(_ raw: Any?) -> Double? {
    if let value = raw as? Double {
      return value
    }
    if let value = raw as? Int {
      return Double(value)
    }
    if let value = raw as? Int64 {
      return Double(value)
    }
    if let value = raw as? NSNumber {
      return value.doubleValue
    }
    return nil
  }

  @available(iOS 16.2, *)
  private func existingSleepActivity(eventId: String) -> Activity<BabyRelaySleepAttributes>? {
    if let activity = sleepActivity as? Activity<BabyRelaySleepAttributes>,
       activity.attributes.eventId == eventId {
      return activity
    }
    return Activity<BabyRelaySleepAttributes>.activities.first {
      $0.attributes.eventId == eventId
    }
  }

  @available(iOS 16.2, *)
  private func endSleepActivities(except eventIdToKeep: String? = nil) {
    for activity in Activity<BabyRelaySleepAttributes>.activities {
      if activity.attributes.eventId == eventIdToKeep {
        sleepActivity = activity
        continue
      }
      Task {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
    if eventIdToKeep == nil {
      sleepActivity = nil
    }
  }

  private func endSleepActivity() {
    guard #available(iOS 16.2, *) else {
      sleepActivity = nil
      return
    }
    endSleepActivities()
  }

  private func startObservingSleepActivityTokens() {
    guard #available(iOS 16.2, *) else { return }
    for activity in Activity<BabyRelaySleepAttributes>.activities {
      observeSleepActivity(activity)
    }

    tokenObserverTasks.append(Task { [weak self] in
      guard let self = self else { return }
      for await activity in Activity<BabyRelaySleepAttributes>.activityUpdates {
        self.observeSleepActivity(activity)
      }
    })

    if #available(iOS 17.2, *) {
      tokenObserverTasks.append(Task { [weak self] in
        guard let self = self else { return }
        for await tokenData in Activity<BabyRelaySleepAttributes>.pushToStartTokenUpdates {
          await self.sendActivityKitToken(
            kind: "pushToStart",
            token: self.hexToken(tokenData),
            eventId: nil
          )
        }
      })
    }
  }

  @available(iOS 16.2, *)
  private func observeSleepActivity(_ activity: Activity<BabyRelaySleepAttributes>) {
    if observedActivityIds.contains(activity.id) { return }
    observedActivityIds.insert(activity.id)
    tokenObserverTasks.append(Task { [weak self] in
      guard let self = self else { return }
      for await tokenData in activity.pushTokenUpdates {
        await self.sendActivityKitToken(
          kind: "activityUpdate",
          token: self.hexToken(tokenData),
          eventId: activity.attributes.eventId
        )
      }
    })
  }

  private func sendActivityKitToken(kind: String, token: String, eventId: String?) async {
    await MainActor.run {
      var payload: [String: Any] = [
        "kind": kind,
        "token": token
      ]
      if let resolvedEventId = eventId {
        payload["eventId"] = resolvedEventId
      }
      sleepActivityTokenChannel?.invokeMethod("activityKitToken", arguments: payload)
    }
  }

  private func hexToken(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
  }
}
