// MARK: - StartBrickData
//
// SwiftData @Model for one Start module brick's state.
// One StartBrickData = one Start brick on the Gantt canvas.
//
// Locked design from Master Design Spec 2026-05-21 Part I § 2:
//   • Exactly ONE Start per chart (the program's entry point).
//   • Tappable by the user; tap fires the outgoing trace.
//   • NO incoming traces — it's the chart's root.
//   • One-shot: fires once per program run; subsequent taps while
//     running are no-ops.
//   • Re-arms when the program terminates (any End reached, all flows
//     complete, etc.) so the user can tap again to start a new run.
//   • Visual: play.circle.fill in green (symmetric with End's red
//     stop.circle.fill).
//   • Full module chrome: user notation + note glyph.
//   • The user's note logs as a `moduleNote` LogEntry at fire time.
//
// Distinct from Trigger (Part I § 3):
//   Start = the ignition key (one per chart, required).
//   Trigger = every other button in the car (many, optional, anywhere).

import Foundation
import SwiftData

@Model
final class StartBrickData {
    /// Stable identifier for cross-reference between bricks on the canvas.
    var id: UUID

    /// User-entered notation — the label that appears on the brick face.
    /// Optional; defaults to "Start" if user leaves it blank.
    var notation: String

    /// User's free-form note about this module.
    /// Edited via the note.text glyph button in the card's top-right
    /// corner or the long-press / right-click context menu. Logged as a
    /// `moduleNote` LogEntry at fire time. Empty string when no note.
    var note: String = ""

    /// Runtime state: has Start fired this program run?
    /// True after the user taps it; reset to false when the program
    /// terminates (any End reached, etc.). Implements the one-shot +
    /// re-arm semantics from Part I § 2.
    var hasFired: Bool = false

    /// Row on the Gantt canvas (vertical position; lower = higher up).
    var order: Int

    /// Column on the Gantt canvas (horizontal position within the row).
    var column: Int

    /// Which saved Gantt chart this brick belongs to.
    var ganttChartId: UUID?

    /// Bookkeeping.
    var createdDate: Date
    var updatedDate: Date

    init(
        id: UUID = UUID(),
        notation: String = "Start",
        note: String = "",
        hasFired: Bool = false,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        self.hasFired = hasFired
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
