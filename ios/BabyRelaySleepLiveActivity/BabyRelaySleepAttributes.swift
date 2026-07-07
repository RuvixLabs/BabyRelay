import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct BabyRelaySleepAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var childName: String
    var startedAtMillis: Double
    var activeSleepCount: Int
    var activeSleepSummary: String

    var startedAt: Date {
      Date(timeIntervalSince1970: startedAtMillis / 1000)
    }
  }

  var eventId: String
  var childName: String
}
