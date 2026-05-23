// MARK: - TimerModulesWidget (Home Screen + Lock Screen)
//
// Home-Screen and lock-screen widget surfaces for TimerModules.
// Reads the current state from an App Group snapshot file written
// by the main app's WidgetSnapshotPublisher.
//
// Vocabulary follows the locked widget shakedown doc
// (TimerModules-iOS-Widget-Shakedown-DRAFT-2026-05-22.html Section B):
//   • RUN  — chart is listening, modules can fire (green dot)
//   • READY  — chart is paused, no firings (grey dot)
//
// The HALT button + Trigger surface buttons in larger sizes need App
// Intents wired to the main app's SignalRouter — those land in a
// later iteration. For now the widget is read-only.
//
// Live per-second countdowns inside the widget rely on
// `Text(timerInterval:)` since widget timelines refresh on the OS's
// schedule (not per-frame). The smoother per-frame countdown lives
// in TimerModulesWidgetLiveActivity.

import WidgetKit
import SwiftUI

struct TimerModulesEntry: TimelineEntry {
    let date: Date
    let snapshot: TimerModulesWidgetSnapshot
}

struct TimerModulesProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerModulesEntry {
        TimerModulesEntry(date: Date(), snapshot: .idle)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerModulesEntry) -> Void) {
        let entry = TimerModulesEntry(date: Date(), snapshot: WidgetSnapshotReader.read())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerModulesEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotReader.read()
        let entry = TimerModulesEntry(date: now, snapshot: snapshot)

        // Tight refresh window when an active timer is approaching its
        // end so the widget catches the RUN → READY transition.
        // Otherwise refresh every 15 minutes (under the OS's typical
        // 15-60 min cap for widget timelines).
        let nextRefresh: Date = {
            if let endsAt = snapshot.activeTimerEndsAt, endsAt > now {
                return endsAt.addingTimeInterval(5)
            } else {
                return now.addingTimeInterval(15 * 60)
            }
        }()

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Entry view (multiplexes by widget family)

struct TimerModulesWidgetEntryView: View {
    var entry: TimerModulesEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:        smallView
        case .systemMedium:       mediumView
        case .systemLarge:        largeView
        case .accessoryRectangular: lockRectangularView
        case .accessoryInline:    lockInlineView
        case .accessoryCircular:  lockCircularView
        default:                  smallView
        }
    }

    // MARK: Common pieces

    private var running: Bool { entry.snapshot.isProgramRunning }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(running ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            Text(running ? "RUN" : "READY")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(running ? Color.green : .secondary)
        }
    }

    private var activeTimerCountdown: some View {
        Group {
            if running,
               let endsAt = entry.snapshot.activeTimerEndsAt,
               let startedAt = entry.snapshot.activeTimerStartedAt,
               endsAt > Date() {
                Text(timerInterval: startedAt...endsAt, countsDown: true)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
            } else {
                Text("—")
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: systemSmall (2×2) — status glance only

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusBadge
            if let chart = entry.snapshot.runningChartName {
                Text(chart)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if running, let notation = entry.snapshot.activeTimerNotation {
                Text(notation)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                activeTimerCountdown
            } else {
                Text("TimerModules")
                    .font(.headline)
                Text("No active run.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: systemMedium (4×2) — status + active timer detail

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                statusBadge
                Spacer()
                if let chart = entry.snapshot.runningChartName {
                    Text(chart)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Divider()
            if running {
                if let notation = entry.snapshot.activeTimerNotation {
                    Text(notation)
                        .font(.headline)
                        .lineLimit(2)
                }
                activeTimerCountdown
            } else {
                Text("TimerModules")
                    .font(.headline)
                Text("Tap the chart's PUSH disc to start a run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: systemLarge (4×4) — status + active timer + Trigger/Halt slots

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusBadge
                Spacer()
                if let chart = entry.snapshot.runningChartName {
                    Text(chart)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Divider()
            if running {
                if let notation = entry.snapshot.activeTimerNotation {
                    Text(notation)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                activeTimerCountdown
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
            } else {
                Text("TimerModules")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Open the app and tap the chart's PUSH disc to start a run.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // Trigger / Halt button slots reserved for the App-Intent
            // interactivity locked in section A of the widget shakedown.
            // Buttons themselves arrive when the App-Intent wiring lands
            // — for now the placeholder copy hints at the feature.
            HStack(spacing: 8) {
                Image(systemName: "stop.circle")
                    .foregroundStyle(.secondary)
                Text("HALT control arrives with App Intents")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Lock-screen rectangular (16:9 thin)

    private var lockRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            statusBadge
            if running, let notation = entry.snapshot.activeTimerNotation {
                Text(notation)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let endsAt = entry.snapshot.activeTimerEndsAt,
                   let startedAt = entry.snapshot.activeTimerStartedAt,
                   endsAt > Date() {
                    Text(timerInterval: startedAt...endsAt, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
            } else {
                Text("No active run")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Lock-screen inline (single line)

    private var lockInlineView: some View {
        if running, let notation = entry.snapshot.activeTimerNotation {
            return Text("\(notation) — RUN")
        } else {
            return Text("TimerModules READY")
        }
    }

    // MARK: Lock-screen circular (gauge-style)

    private var lockCircularView: some View {
        ZStack {
            Circle()
                .stroke(running ? Color.green : Color.secondary.opacity(0.5), lineWidth: 2)
            Image(systemName: running ? "play.fill" : "pause")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(running ? Color.green : .secondary)
        }
    }
}

// MARK: - Widget registration

struct TimerModulesWidget: Widget {
    let kind: String = "TimerModulesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerModulesProvider()) { entry in
            TimerModulesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TimerModules")
        .description("Shows the currently running chart, active Timer, and RUN / READY status.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}

#Preview(as: .systemSmall) {
    TimerModulesWidget()
} timeline: {
    TimerModulesEntry(date: .now, snapshot: .idle)
    TimerModulesEntry(date: .now, snapshot: TimerModulesWidgetSnapshot(
        isProgramRunning: true,
        runningChartName: "Work Day",
        activeTimerNotation: "Deep Work Block",
        activeTimerStartedAt: Date(),
        activeTimerEndsAt: Date().addingTimeInterval(25 * 60),
        publishedAt: Date()
    ))
}

#Preview(as: .systemLarge) {
    TimerModulesWidget()
} timeline: {
    TimerModulesEntry(date: .now, snapshot: TimerModulesWidgetSnapshot(
        isProgramRunning: true,
        runningChartName: "Work Day",
        activeTimerNotation: "Deep Work Block",
        activeTimerStartedAt: Date(),
        activeTimerEndsAt: Date().addingTimeInterval(25 * 60),
        publishedAt: Date()
    ))
}

#Preview(as: .accessoryRectangular) {
    TimerModulesWidget()
} timeline: {
    TimerModulesEntry(date: .now, snapshot: TimerModulesWidgetSnapshot(
        isProgramRunning: true,
        runningChartName: "Work Day",
        activeTimerNotation: "Deep Work Block",
        activeTimerStartedAt: Date(),
        activeTimerEndsAt: Date().addingTimeInterval(25 * 60),
        publishedAt: Date()
    ))
}
