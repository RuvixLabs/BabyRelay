import Flutter
import ActivityKit
import UserNotifications
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var sleepActivity: Any?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureSleepActivityChannel(messenger: engineBridge.applicationRegistrar.messenger())
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
    let startedAt = Date(timeIntervalSince1970: startedAtMillis / 1000)
    let state = BabyRelaySleepAttributes.ContentState(
      childName: childName,
      startedAt: startedAt,
      activeSleepCount: activeSleepCount,
      activeSleepSummary: activeSleepSummary
    )

    if let activity = existingSleepActivity(eventId: eventId) {
      sleepActivity = activity
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
        pushType: nil
      )
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
}
