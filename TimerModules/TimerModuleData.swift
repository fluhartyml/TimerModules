// MARK: - TimerModuleData
//
// SwiftData @Model for one Timer module brick's state.
// One TimerModuleData = one Timer brick on the Gantt canvas.
//
// Persists across app launches (Section 3.1 of roadmap — user-
// created timers survive app close).

import Foundation
import SwiftData

enum TimerMode: String, Codable {
    case countdown
    case countUp
}

@Model
final class TimerModuleData {
    /// Stable identifier for cross-reference between bricks on the canvas.
    var id: UUID

    /// User-entered notation — the label that appears prominently on the
    /// brick face so the Gantt is self-explanatory at a glance.
    /// Required UX element per roadmap Section 1.5.1.
    var notation: String

    /// Countdown vs. count-up. Both modes ship in v1.0
    /// (roadmap Section 3.2).
    var mode: TimerMode

    /// For countdown mode: the total duration in seconds when the timer
    /// is reset. For count-up mode: ignored (the brick just accumulates).
    var durationSeconds: TimeInterval

    /// Accumulated elapsed seconds at the last stop. Combined with
    /// runningSince to compute current elapsed time. The HOS pattern
    /// (accumulatedSeconds + (now − runningSince)) survives stop/start
    /// cleanly and is lifted verbatim per roadmap Section 2.
    var accumulatedSeconds: TimeInterval

    /// Non-nil while the timer is running; nil when idle/paused/done.
    /// Used together with accumulatedSeconds for elapsed-time math.
    var runningSince: Date?

    /// Position on the Gantt canvas. Lower = higher row. Updated by the
    /// canvas at M2.
    var order: Int

    /// Bookkeeping.
    var createdDate: Date
    var updatedDate: Date

    init(
        id: UUID = UUID(),
        notation: String = "Timer",
        mode: TimerMode = .countUp,
        durationSeconds: TimeInterval = 25 * 60,
        accumulatedSeconds: TimeInterval = 0,
        runningSince: Date? = nil,
        order: Int = 0,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.accumulatedSeconds = accumulatedSeconds
        self.runningSince = runningSince
        self.order = order
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
