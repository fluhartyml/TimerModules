// MARK: - TimerModulesWidgetLiveActivity
//
// Live Activity for an active Timer in TimerModules. Replaces the
// Xcode-generated Hello-emoji stub.
//
// Renders on iOS:
//   • Lock Screen: chart name + timer label + live countdown numerals
//     (driven by Text(timerInterval:countsDown:) so the system handles
//     per-second updates without ContentState churn)
//   • Dynamic Island compact: timer.fill + remaining seconds tail
//   • Dynamic Island expanded: full timer details
//   • Dynamic Island minimal: timer icon
//
// Per Master Design Spec — Live Activity is the truly-live "Live Tile"
// surface (the Home Screen widget is timeline-refresh-bounded and
// can't show smooth countdown numerals).

import ActivityKit
import WidgetKit
import SwiftUI

/// Shared with the main app (defined identically there too).
/// ActivityKit serializes ContentState as JSON; the duplicate types
/// interoperate via matching field names + Codable encoding.
struct TimerModulesActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the timer was started.
        var startDate: Date
        /// When the timer is scheduled to fire. Set only for countdown
        /// mode; SwiftUI's Text(timerInterval:) uses this for live
        /// per-second rendering without ContentState updates.
        var endDate: Date
        /// True when the user pauses / when the program halts.
        var isPaused: Bool
        /// True after the timer completes (countdown reached 0 or
        /// user marked complete). View shows "DONE".
        var isComplete: Bool
    }

    /// User's chart name (the Gantt chart this timer belongs to).
    var chartName: String
    /// User's notation for this specific Timer module.
    var timerNotation: String
}

struct TimerModulesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerModulesActivityAttributes.self) { context in
            // Lock Screen / banner UI.
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.cyan)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isComplete {
                        Text("DONE")
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Text(timerInterval: context.state.startDate...context.state.endDate,
                             countsDown: !context.state.isPaused)
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.chartName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.timerNotation)
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                if context.state.isComplete {
                    Text("✓").foregroundStyle(.green)
                } else {
                    Text(timerInterval: context.state.startDate...context.state.endDate,
                         countsDown: !context.state.isPaused)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.isComplete ? "checkmark.circle.fill" : "timer")
                    .foregroundStyle(context.state.isComplete ? .green : .cyan)
            }
            .keylineTint(Color.cyan)
        }
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {
    let attributes: TimerModulesActivityAttributes
    let state: TimerModulesActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
                Text(attributes.chartName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if state.isComplete {
                    Text("DONE")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            Text(attributes.timerNotation)
                .font(.headline)
                .foregroundStyle(.primary)
            if !state.isComplete {
                Text(timerInterval: state.startDate...state.endDate,
                     countsDown: !state.isPaused)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("✓")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
    }
}

// MARK: - Previews

extension TimerModulesActivityAttributes {
    fileprivate static var preview: TimerModulesActivityAttributes {
        TimerModulesActivityAttributes(
            chartName: "Work Day",
            timerNotation: "Deep Work Block"
        )
    }
}

extension TimerModulesActivityAttributes.ContentState {
    fileprivate static var running: TimerModulesActivityAttributes.ContentState {
        let now = Date()
        return TimerModulesActivityAttributes.ContentState(
            startDate: now,
            endDate: now.addingTimeInterval(25 * 60),
            isPaused: false,
            isComplete: false
        )
    }
    fileprivate static var done: TimerModulesActivityAttributes.ContentState {
        let now = Date()
        return TimerModulesActivityAttributes.ContentState(
            startDate: now.addingTimeInterval(-25 * 60),
            endDate: now,
            isPaused: false,
            isComplete: true
        )
    }
}

#Preview("Lock Screen", as: .content, using: TimerModulesActivityAttributes.preview) {
   TimerModulesWidgetLiveActivity()
} contentStates: {
    TimerModulesActivityAttributes.ContentState.running
    TimerModulesActivityAttributes.ContentState.done
}
