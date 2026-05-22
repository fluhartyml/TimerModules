// MARK: - BatteryBrickData
//
// SwiftData @Model for one Battery module brick.
//
// Locked design from Master Design Spec 12.11:
//   • 1×1 footprint (just battery %).
//   • iPhone/iPad only — Mac variant has different semantics.
//   • NO trace I/O in v1.0.

import Foundation
import SwiftData

@Model
final class BatteryBrickData {
    var id: UUID = UUID()
    var notation: String = "Battery"
    var note: String = ""

    var order: Int = 0
    var column: Int = 0
    var ganttChartId: UUID?
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        notation: String = "Battery",
        note: String = "",
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
