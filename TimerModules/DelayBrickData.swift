// MARK: - DelayBrickData
//
// SwiftData @Model for one Delay module brick's state.
// One DelayBrickData = one Delay brick on the Gantt canvas.
//
// Locked design from Master Design Spec Part II §18:
//   • 1×1 icon footprint (~60×60pt).
//   • ONE input ("signal in"), ONE output ("delayed signal out").
//   • Display range 0-9 = ten distinct values = ten seconds of held
//     time per module. Computer-counting-from-0 convention:
//     display "0" = 1 second of held time (final tick before firing).
//     Display "9" = 10 seconds of held time.
//   • 7-segment crosswalk countdown when in flight (9 → 0).
//   • Composable in series for longer waits.
//   • Idle face shows the static configured display value.
//
// Distinct from Timer (Part II §14):
//   Delay = small composable primitive for cascade spacing.
//   Timer = focal countdown when the user wants a single visible
//           time-block (counts up or down, configurable in minutes).

import Foundation
import SwiftData

@Model
final class DelayBrickData {
    /// Stable identifier for cross-reference between bricks on the canvas.
    var id: UUID

    /// User-entered notation — defaults to "Delay" if blank.
    var notation: String

    /// User's free-form note about this module. Logged as a
    /// `moduleNote` LogEntry at fire time.
    var note: String = ""

    /// Configured DISPLAY value (0-9 per Master Design Spec 18.4).
    /// Held seconds = displayValue + 1 per the computer-counting-from-0
    /// convention. Display 0 = 1 second; display 9 = 10 seconds.
    var displayValue: Int = 0

    /// Runtime state: the current displayed digit while counting
    /// down. Nil when idle (no signal in flight); when a signal
    /// arrives, this resets to displayValue and ticks down to 0
    /// before firing the outgoing trace.
    var currentCountdown: Int?

    /// Runtime state: timestamp of the last tick decrement (used by
    /// SignalRouter to know when to advance the countdown via the
    /// ProgramRunner heartbeat).
    var countdownStartedAt: Date?

    /// Row on the Gantt canvas (vertical position).
    var order: Int

    /// Column on the Gantt canvas (horizontal position within row).
    var column: Int

    /// Which saved Gantt chart this brick belongs to.
    var ganttChartId: UUID?

    /// Bookkeeping.
    var createdDate: Date
    var updatedDate: Date

    init(
        id: UUID = UUID(),
        notation: String = "Delay",
        note: String = "",
        displayValue: Int = 0,
        currentCountdown: Int? = nil,
        countdownStartedAt: Date? = nil,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        // Clamp to locked range [0,9] per Master Design Spec 18.4.
        self.displayValue = max(0, min(9, displayValue))
        self.currentCountdown = currentCountdown
        self.countdownStartedAt = countdownStartedAt
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }

    /// Held seconds for this Delay = displayValue + 1.
    /// (Display "0" holds 1 second; display "9" holds 10 seconds.)
    var heldSeconds: Int { displayValue + 1 }
}
