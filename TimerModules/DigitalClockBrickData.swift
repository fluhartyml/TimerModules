// MARK: - DigitalClockBrickData
//
// SwiftData @Model for one Digital Clock module brick on the canvas.
//
// Locked design from Master Design Spec Section 12:
//   • 2×1 horizontal footprint (HH:MM strip).
//   • Passive readout — current system time.
//   • NO trace I/O in v1.0 (per spec — shakedown may add later).
//
// The actual time display is rendered in DigitalClockBrickView,
// which reads Date() and refreshes via a Timer.publish.
// This @Model just persists the brick's position + identity.

import Foundation
import SwiftData

@Model
final class DigitalClockBrickData {
    var id: UUID
    var notation: String
    var note: String = ""

    /// Whether to render in 24-hour mode (default) vs. 12-hour AM/PM.
    var use24HourFormat: Bool

    var order: Int
    var column: Int
    var ganttChartId: UUID?
    var createdDate: Date
    var updatedDate: Date

    init(
        id: UUID = UUID(),
        notation: String = "Clock",
        note: String = "",
        use24HourFormat: Bool = false,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        self.use24HourFormat = use24HourFormat
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
