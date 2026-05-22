// MARK: - TimerModulesWidget (Home Screen)
//
// Home Screen widget that displays the current TimerModules state
// from the App Group snapshot file (written by the main app via
// WidgetSnapshotPublisher).
//
// Per Master Design Spec 14.1, Home Screen widgets are timeline-
// refreshed (not truly live like the Live Activity). This widget
// is best for "currently running: X" status displays. The smooth
// per-second countdown lives in TimerModulesWidgetLiveActivity.
//
// Replaces the Xcode-generated time + emoji stub.

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

        // If a timer is actively counting down, refresh near its end
        // so the widget catches the transition to idle. Otherwise
        // refresh every 5 minutes.
        let nextRefresh: Date = {
            if let endsAt = snapshot.activeTimerEndsAt, endsAt > now {
                return endsAt.addingTimeInterval(5)
            } else {
                return now.addingTimeInterval(5 * 60)
            }
        }()

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

struct TimerModulesWidgetEntryView: View {
    var entry: TimerModulesEntry

    var body: some View {
        if entry.snapshot.isProgramRunning {
            runningView
        } else {
            idleView
        }
    }

    // MARK: Running state

    private var runningView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.cyan)
                    .font(.caption)
                Text(entry.snapshot.runningChartName ?? "Running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let notation = entry.snapshot.activeTimerNotation {
                Text(notation)
                    .font(.headline)
                    .lineLimit(2)
            }
            if let endsAt = entry.snapshot.activeTimerEndsAt,
               let startedAt = entry.snapshot.activeTimerStartedAt,
               endsAt > Date() {
                Text(timerInterval: startedAt...endsAt, countsDown: true)
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Idle state

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "heart.slash.fill")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.caption)
                Text("Idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("TimerModules")
                .font(.headline)
            Text("Tap a Start module on the canvas to begin a run.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }
}

struct TimerModulesWidget: Widget {
    let kind: String = "TimerModulesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerModulesProvider()) { entry in
            TimerModulesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TimerModules")
        .description("Shows the currently running chart and active Timer.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
