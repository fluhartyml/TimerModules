// MARK: - CalendarDateBrickData
//
// SwiftData @Model for one Calendar Date module brick.
//
// Locked design from Master Design Spec Section 12.10:
//   • 2×1 horizontal footprint.
//   • Passive readout — current system date ("May 21 Thu" format).
//   • NO trace I/O in v1.0.

import Foundation
import SwiftData

@Model
final class CalendarDateBrickData {
    var id: UUID = UUID()
    var notation: String = "Date"
    var note: String = ""

    /// Display style: 0 = "May 21 Thu", 1 = "5/21/26", 2 = "Thu May 21"
    var formatStyleRaw: Int = 0

    var order: Int = 0
    var column: Int = 0
    var ganttChartId: UUID?
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        notation: String = "Date",
        note: String = "",
        formatStyleRaw: Int = 0,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        self.formatStyleRaw = formatStyleRaw
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
