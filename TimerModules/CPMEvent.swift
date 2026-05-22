// MARK: - CPMEvent
//
// SwiftData @Model for one row in a CPM's event grid.
// Each event has its own recurrence rule and a list of port numbers
// it fires when its rule matches the current calendar moment.
//
// Locked design — three-column event grid:
//   Col 1: eventName (the row's name / identifier)
//   Col 2: briefDescription (22-character user description)
//   Col 3: portNumbers (which output port(s) on the parent CPM this fires)
//
// Phase 1 scaffold — establishes the data shape. Recurrence-rule fields
// are stubbed for now (modeRaw + a JSON params blob); per-mode editors,
// EventKit roundtripping, and notification scheduling arrive in later
// phases.

import Foundation
import SwiftData

@Model
final class CPMEvent {
    /// Stable identifier.
    var id: UUID = UUID()

    /// Owning CPM's id. Foreign-key style (matches project convention
    /// of `ganttChartId: UUID?` etc.) — CloudKit-friendly. Views query
    /// CPMEvents by `ownerCPMId == cpm.id` rather than walking a Swift
    /// reference. CPM deletion must explicitly cascade-delete the
    /// matching CPMEvents (handled in GanttCanvasView.deleteCanvasBrick).
    var ownerCPMId: UUID?

    /// Col 1: event name (free-form identifier; not user-facing on canvas,
    /// surfaces inside the CPM Smart Stack's event-grid face).
    var eventName: String = ""

    /// Col 2: 22-character user description. Hard cap enforced by the
    /// editor; persisted value is the trimmed string.
    var briefDescription: String = ""

    /// Col 3: which port number(s) on the parent CPM this event fires.
    /// Each value must be in 1...CPMBrickData.portCount (1...52). Empty
    /// = unassigned (event tracked but doesn't fire any port).
    var portNumbers: [Int] = []

    /// Per-event Notify toggle (locked Section J): default ON. Toggling
    /// OFF suppresses the iOS local notification when this event fires;
    /// the log still records the firing.
    var notifyEnabled: Bool = true

    /// Whether this event is "Protected" (Section S scaffold) — its
    /// active window suppresses unrelated events. Section S/T overlap
    /// is unresolved per the spec; the field is here for future use.
    var isProtected: Bool = false

    /// Stored discriminator for the recurrence-rule mode.
    /// One of CPMEventRecurrenceMode rawValues:
    ///   "oneOff" — single specific date
    ///   "ordinalWeekday" — 1st/2nd/3rd/4th/last <weekday> of month
    ///   "lastDayOfMonth" — variable 28/29/30/31
    ///   "everyNMonths" — every-N-months on a chosen weekday
    /// Stored as raw String so SwiftData migration is straightforward.
    var recurrenceModeRaw: String = CPMEventRecurrenceMode.oneOff.rawValue

    /// JSON-encoded parameter blob for the recurrence-rule mode.
    /// Shape depends on recurrenceModeRaw; per-mode editors decode + encode.
    /// Phase 1 stub — fully populated in Phase 4.
    var recurrenceParamsJSON: String = "{}"

    /// Bookkeeping.
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        ownerCPMId: UUID? = nil,
        eventName: String = "",
        briefDescription: String = "",
        portNumbers: [Int] = [],
        notifyEnabled: Bool = true,
        isProtected: Bool = false,
        recurrenceModeRaw: String = CPMEventRecurrenceMode.oneOff.rawValue,
        recurrenceParamsJSON: String = "{}",
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.ownerCPMId = ownerCPMId
        self.eventName = eventName
        // Hard-cap brief description at 22 chars per the locked event-grid spec.
        self.briefDescription = String(briefDescription.prefix(22))
        // Clamp port numbers to the v1.0 valid range and de-duplicate.
        let validPorts = portNumbers
            .filter { (1...CPMBrickData.portCount).contains($0) }
        self.portNumbers = Array(Set(validPorts)).sorted()
        self.notifyEnabled = notifyEnabled
        self.isProtected = isProtected
        self.recurrenceModeRaw = recurrenceModeRaw
        self.recurrenceParamsJSON = recurrenceParamsJSON
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}

/// Discriminator for the four locked recurrence-rule vocabulary types
/// from the spec (Section "Locked So Far"). Used as the rawValue of
/// CPMEvent.recurrenceModeRaw.
enum CPMEventRecurrenceMode: String, CaseIterable, Codable {
    case oneOff
    case ordinalWeekday
    case lastDayOfMonth
    case everyNMonths

    var displayName: String {
        switch self {
        case .oneOff:         return "On a specific date"
        case .ordinalWeekday: return "Nth weekday of the month"
        case .lastDayOfMonth: return "Last day of the month"
        case .everyNMonths:   return "Every N months on a weekday"
        }
    }
}
