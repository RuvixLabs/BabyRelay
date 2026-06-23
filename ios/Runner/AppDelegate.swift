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
      let startedAtMillis = payload["startedAtMillis"] as? Double
    else {
      return
    }
    let activeSleepCount = payload["activeSleepCount"] as? Int ?? 1
    let startedAt = Date(timeIntervalSince1970: startedAtMillis / 1000)
    let state = BabyRelaySleepAttributes.ContentState(
      childName: childName,
      startedAt: startedAt,
      activeSleepCount: activeSleepCount
    )

    if let activity = sleepActivity as? Activity<BabyRelaySleepAttributes>,
       activity.attributes.eventId == eventId {
      Task {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      }
      return
    }

    endSleepActivity()
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

  private func endSleepActivity() {
    guard #available(iOS 16.2, *),
      let activity = sleepActivity as? Activity<BabyRelaySleepAttributes>
    else {
      sleepActivity = nil
      return
    }
    sleepActivity = nil
    Task {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
