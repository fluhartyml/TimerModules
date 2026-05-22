// MARK: - TextLCDBrickData
//
// SwiftData @Model for one Text LCD module brick.
// One TextLCDBrickData = one Text LCD brick on the Gantt canvas.
//
// Locked design from Master Design Spec Part II §19:
//   • 4×1 horizontal footprint (single-line LCD strip).
//   • 4 input ports per LCD module — one per icon block.
//   • Each port has a 22-character text box for the configured value.
//   • Initial state (no port fired yet) = the module's name (19.4).
//   • Persistent display — like e-ink paper. Last-fired message
//     stays until another port fires (19.5).
//   • Port-per-output-state addressing per 16.1: TraceData stores
//     destinationPortIndex (0-3) to indicate which port a trace
//     targets.

import Foundation
import SwiftData

@Model
final class TextLCDBrickData {
    /// Stable identifier.
    var id: UUID = UUID()

    /// User-entered notation — doubles as the "idle state" display
    /// text per Master Design Spec 19.4. Defaults to "Text LCD".
    var notation: String = "Text LCD"

    /// User's free-form note.
    var note: String = ""

    /// The 4 canned-message slots (22 char max each per 19.3).
    /// Index 0 = port 1, index 1 = port 2, etc.
    var cannedMessages: [String] = ["", "", "", ""]

    /// Runtime state: index of the most-recently-fired port (0-3),
    /// or nil if no port has fired this run. When non-nil, the
    /// view displays cannedMessages[currentPortIndex] (the
    /// persistent e-ink-style display per 19.5).
    var currentPortIndex: Int?

    /// Row on the Gantt canvas.
    var order: Int = 0

    /// Column on the Gantt canvas.
    var column: Int = 0

    /// Which saved Gantt chart this brick belongs to.
    var ganttChartId: UUID?

    /// Bookkeeping.
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    /// Locked port count for v1.0 per 19.3.
    static let portCount: Int = 4

    /// Locked per-port character limit per 19.3.
    static let charLimit: Int = 22

    init(
        id: UUID = UUID(),
        notation: String = "Text LCD",
        note: String = "",
        cannedMessages: [String] = ["", "", "", ""],
        currentPortIndex: Int? = nil,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        // Pad / truncate to the locked port count.
        var msgs = cannedMessages
        while msgs.count < Self.portCount { msgs.append("") }
        if msgs.count > Self.portCount { msgs = Array(msgs.prefix(Self.portCount)) }
        self.cannedMessages = msgs
        self.currentPortIndex = currentPortIndex
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }

    /// The text currently shown on the LCD's face.
    /// - If a port has fired: that port's configured canned message
    ///   (or the module's name if the canned message is empty).
    /// - If no port has fired yet: the module's name (per 19.4).
    var displayedText: String {
        if let i = currentPortIndex, i >= 0, i < cannedMessages.count {
            let canned = cannedMessages[i]
            return canned.isEmpty ? notation : canned
        }
        return notation
    }
}
