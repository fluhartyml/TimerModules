// MARK: - GanttChartData
//
// SwiftData @Model for one saved Gantt chart. Each chart is a
// self-contained "program" — its own canvas of bricks + its own
// execution log. The app supports multiple charts; users can
// switch between them, rename them, duplicate, delete.

import Foundation
import SwiftData

@Model
final class GanttChartData {
    /// Stable identifier — referenced by every brick's ganttChartId.
    var id: UUID

    /// User-visible name of the chart (shown in the chart list and
    /// in printable exports). Defaults to "New Gantt" until renamed.
    var name: String

    /// Optional user notation / description.
    var notation: String

    /// How many columns wide this chart's grid is (user-defined per
    /// chart, Michael 2026-05-19). Default 1 = single-column (the
    /// pre-M5.5 vertical-stack layout). Increase to lay bricks out
    /// in parallel tracks at the same horizontal position.
    var columnCount: Int

    /// Bookkeeping.
    var createdDate: Date
    var updatedDate: Date

    /// Last time the user opened this chart — used to sort the
    /// chart list (most-recently-used first) and to auto-select
    /// the active chart on app launch.
    var lastOpenedDate: Date

    init(
        id: UUID = UUID(),
        name: String = "New Gantt",
        notation: String = "",
        columnCount: Int = 1,
        createdDate: Date = Date(),
        updatedDate: Date = Date(),
        lastOpenedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notation = notation
        self.columnCount = columnCount
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.lastOpenedDate = lastOpenedDate
    }
}
