// MARK: - WidgetSnapshotReader (widget extension side)
//
// Widget-extension copy of the snapshot type + reader. Pairs with
// TimerModules/WidgetSnapshotPublisher.swift in the main app target.
// Filesystem-synced Xcode 16 project groups don't share files across
// targets without manual project file edits; the canonical workaround
// is duplicate type definitions matched by Codable JSON encoding.
//
// **Keep TimerModulesWidgetSnapshot IN SYNC with the main app's copy.**

import Foundation

struct TimerModulesWidgetSnapshot: Codable {
    var isProgramRunning: Bool
    var runningChartName: String?
    var activeTimerNotation: String?
    var activeTimerStartedAt: Date?
    var activeTimerEndsAt: Date?
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

enum WidgetSnapshotReader {
    static let appGroupID = "group.com.nightgard.timermodules"

    static func read() -> TimerModulesWidgetSnapshot {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
        else {
            return .idle
        }
        guard let data = try? Data(contentsOf: url) else {
            return .idle
        }
        return (try? JSONDecoder().decode(TimerModulesWidgetSnapshot.self, from: data)) ?? .idle
    }
}
