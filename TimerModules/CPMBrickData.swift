// MARK: - CPMBrickData
//
// SwiftData @Model for one Calendar Processing Module (CPM) brick.
// One CPMBrickData = one CPM on the Gantt canvas.
//
// Locked design from TimerModules-Brain-Module-Refinement-2026-05-22.html
// (the CPM refinement spec; canonical copy in Library/Reference-Docs/).
//
// v1.0 essentials:
//   • 4×4 working grid on the canvas (Apple-widget-compatible).
//     The 5th row title chrome is an in-app holder added by the view layer.
//   • 52 numbered output ports (v1.0 cap). Ports are implicit — port N is
//     just the integer N (1...52); we don't store the empty port pool.
//   • Bidirectional Apple Calendar bridge via EventKit:
//     - READ: poll all user calendars (read-only)
//     - WRITE: only to CPM's own dedicated calendar (writeCalendarIdentifier).
//   • Events held by CPM via a one-to-many relationship to CPMEvent.
//   • Single CPM body, two rendering frames (in-app canvas + future
//     iOS Home Screen widget).
//
// Phase 1 scaffold — establishes the data shape so build + persistence
// compile. Smart Stack faces, Setup Assistant wizard, EventKit hookup,
// and Internal Focus States arrive in later phases per the locked build
// order ("get the 4×4 working module in place first").

import Foundation
import SwiftData

@Model
final class CPMBrickData {
    /// Stable identifier for cross-reference between bricks on the canvas.
    var id: UUID = UUID()

    /// Internal notation — used for log entries and cross-references.
    /// User-visible label lives in adjacent TextLCD modules per the locked
    /// canvas-labeling rule. Defaults to "CPM".
    var notation: String = "CPM"

    /// User's free-form note about this CPM instance. Edited via the
    /// note.text glyph button or long-press / right-click context menu.
    var note: String = ""

    /// The events held by this CPM. Each CPMEvent has its own recurrence
    /// rule and the port number(s) it fires when triggered. Many-to-many
    /// event-to-port mapping lives on the CPMEvent (multi-valued portNumbers
    /// array; many events may share a port number).
    @Relationship(deleteRule: .cascade, inverse: \CPMEvent.ownerCPM)
    var events: [CPMEvent] = []

    /// EKCalendar identifier for the CPM's dedicated write-back calendar
    /// in Apple Calendar (the "TimerModulesCPM" calendar). Created on
    /// first use when the user grants EventKit write permission. nil until
    /// the calendar exists.
    var writeCalendarIdentifier: String?

    /// v1.0 cap on the number of output ports a CPM exposes. 52 chosen to
    /// cover weekly / monthly / quarterly / annual cadences (your call
    /// 2026-05-22). Per the spec lock, port count is fixed at this constant;
    /// individual ports become "live" when at least one CPMEvent references
    /// them in its portNumbers list.
    static let portCount: Int = 52

    /// Row on the Gantt canvas (vertical position; lower = higher up).
    var order: Int = 0

    /// Column on the Gantt canvas (horizontal position within the row).
    var column: Int = 0

    /// Which saved Gantt chart this brick belongs to.
    var ganttChartId: UUID?

    /// Bookkeeping.
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        notation: String = "CPM",
        note: String = "",
        events: [CPMEvent] = [],
        writeCalendarIdentifier: String? = nil,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        self.events = events
        self.writeCalendarIdentifier = writeCalendarIdentifier
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
