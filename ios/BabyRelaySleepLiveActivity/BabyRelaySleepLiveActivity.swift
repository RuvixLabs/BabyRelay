import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BabyRelaySleepLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 16.1, *) {
      BabyRelaySleepLiveActivity()
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
struct BabyRelaySleepLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BabyRelaySleepAttributes.self) { context in
      LockScreenSleepView(context: context)
        .activityBackgroundTint(Color(red: 0.12, green: 0.15, blue: 0.30))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.state.childName, systemImage: "moon.stars.fill")
            .font(.caption.weight(.semibold))
        }
        DynamicIslandExpandedRegion(.trailing) {
          SleepTimerText(startedAt: context.state.startedAt, font: .title3.monospacedDigit().weight(.bold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.activeSleepCount > 1
               ? "\(context.state.activeSleepCount) sleep timers running"
               : "BabyRelay is tracking this sleep")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.74))
        }
      } compactLeading: {
        Image(systemName: "moon.stars.fill")
          .foregroundStyle(.white)
      } compactTrailing: {
        SleepTimerText(startedAt: context.state.startedAt, font: .caption2.monospacedDigit().weight(.bold))
      } minimal: {
        Image(systemName: "moon.fill")
          .foregroundStyle(.white)
      }
      .keylineTint(Color(red: 0.95, green: 0.79, blue: 0.58))
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct LockScreenSleepView: View {
  let context: ActivityViewContext<BabyRelaySleepAttributes>

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.14))
        Image(systemName: "moon.stars.fill")
          .font(.title2)
          .foregroundStyle(Color(red: 0.95, green: 0.79, blue: 0.58))
      }
      .frame(width: 46, height: 46)

      VStack(alignment: .leading, spacing: 4) {
        Text("\(context.state.childName) is sleeping")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.78))
        SleepTimerText(startedAt: context.state.startedAt, font: .largeTitle.monospacedDigit().weight(.heavy))
        Text(context.state.activeSleepCount > 1
             ? "\(context.state.activeSleepCount) active sleep timers"
             : "Started \(context.state.startedAt.formatted(date: .omitted, time: .shortened))")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.70))
      }
      Spacer(minLength: 0)
    }
    .padding(16)
  }
}

private struct SleepTimerText: View {
  let startedAt: Date
  let font: Font

  var body: some View {
    Text(startedAt, style: .timer)
      .font(font)
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.78)
  }
}
