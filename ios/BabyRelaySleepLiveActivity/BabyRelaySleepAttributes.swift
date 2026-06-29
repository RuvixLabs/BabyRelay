import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct BabyRelaySleepAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var childName: String
    var startedAt: Date
    var activeSleepCount: Int
    var activeSleepSummary: String
  }

  var eventId: String
  var childName: String
}
