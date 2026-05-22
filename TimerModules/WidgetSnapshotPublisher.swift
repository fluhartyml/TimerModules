// MARK: - WidgetSnapshotPublisher
//
// Main-app side of the Home Screen widget data pipeline. Writes a JSON
// snapshot to the App Group container so the widget extension's timeline
// provider can read it. Updates the widget timeline on every publish.
//
// Pairs with TimerModulesWidget/WidgetSnapshotReader.swift in the widget
// extension target. The TimerModulesWidgetSnapshot struct is defined
// identically in both files; ActivityKit's same Codable round-trip
// applies (matching JSON encoding is enough — separate Swift types
// across module boundaries are fine).
//
// Called from SignalRouter at every state change worth surfacing to the
// widget: program start, timer start, timer completion, program end.

import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Snapshot shape — shared with the widget extension by duplicate
/// definition. Keep IN SYNC with TimerModulesWidget's copy.
struct TimerModulesWidgetSnapshot: Codable {
    /// True when at least one chart is actively running.
    var isProgramRunning: Bool
    /// Name of the chart that has running activity, or nil.
    var runningChartName: String?
    /// The active Timer's notation (label), or nil if no Timer running.
    var activeTimerNotation: String?
    /// When the active Timer began running, or nil.
    var activeTimerStartedAt: Date?
    /// When the active Timer will fire (countdown end), or nil for
    /// count-up Timers or when nothing is running.
    var activeTimerEndsAt: Date?
    /// Timestamp of the last snapshot publish, used by the widget
    /// to display a "last updated" hint if anyone wants it.
    var publishedAt: Date

    static var idle: TimerModulesWidgetSnapshot {
        TimerModulesWidgetSnapshot(
            isProgramRunning: false,
            runningChartName: nil,
            activeTimerNotation: nil,
            activeTimerStartedAt: nil,
            activeTimerEndsAt: nil,
            publishedAt: Date()
        )
    }
}

struct WidgetSnapshotPublisher {
    /// Locked App Group ID — matches both entitlements files.
    static let appGroupID = "group.com.nightgard.timermodules"

    private static func snapshotURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    /// Build a snapshot from the current SwiftData state of the chart's
    /// timers + Start module, write it to the App Group container, and
    /// kick the widget center to reload its timelines. Called by
    /// SignalRouter on every state transition worth surfacing.
    static func publish(chartId: UUID, in context: ModelContext) {
        let snapshot = buildSnapshot(chartId: chartId, in: context)
        writeAndReload(snapshot)
    }

    /// Publish the idle/empty snapshot (no chart running). Called from
    /// stopAllRunningTimers / endBrickReached so the widget reflects
    /// the program ending.
    static func publishIdle() {
        writeAndReload(.idle)
    }

    private static func buildSnapshot(chartId: UUID, in context: ModelContext) -> TimerModulesWidgetSnapshot {
        // Find the running Timer (if any) for this chart.
        let runningTimers = (try? context.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.runningSince != nil }
            )
        )) ?? []

        guard let firstRunning = runningTimers.first else {
            return .idle
        }

        // Fetch chart name for context.
        let chartName: String = {
            let charts = (try? context.fetch(
                FetchDescriptor<GanttChartData>(
                    predicate: #Predicate { $0.id == chartId }
                )
            )) ?? []
            return charts.first?.name ?? "Chart"
        }()

        let startedAt = firstRunning.runningSince
        let endsAt: Date? = {
            guard firstRunning.mode == .countdown,
                  let started = startedAt
            else { return nil }
            return started.addingTimeInterval(firstRunning.durationSeconds)
        }()

        return TimerModulesWidgetSnapshot(
            isProgramRunning: true,
            runningChartName: chartName,
            activeTimerNotation: firstRunning.notation.isEmpty ? "Timer" : firstRunning.notation,
            activeTimerStartedAt: startedAt,
            activeTimerEndsAt: endsAt,
            publishedAt: Date()
        )
    }

    private static func writeAndReload(_ snapshot: TimerModulesWidgetSnapshot) {
        guard let url = snapshotURL() else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Silent — widget falls back to its idle state if read fails.
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
