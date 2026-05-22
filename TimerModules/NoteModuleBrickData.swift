// MARK: - NoteModuleBrickData
//
// SwiftData @Model for one Note module brick.
//
// Locked design from Master Design Spec Part II §22.7:
//   • 4×4 footprint — large widget canvas annotation.
//   • Smart Stack of swipable pages (1-99 pages, user-configurable;
//     starts at 1 blank page).
//   • Plain text only, no rich text (22.7.2).
//   • 400 chars per page max (22.7.3).
//   • Long-press / right-click → edit page (22.7.4).
//   • Fires an output trace when user reaches the last page
//     (22.7.5). One-shot per program run; resets on Start tap.

import Foundation
import SwiftData

@Model
final class NoteModuleBrickData {
    var id: UUID = UUID()
    var notation: String = "Note"
    var note: String = ""

    /// Array of page text contents. Index 0 = first page.
    var pages: [String] = [""]

    /// Runtime / UI state: which page is currently displayed.
    var currentPageIndex: Int = 0

    /// Runtime state: whether the "last page reached" output has
    /// fired this program run. Reset to false on Start tap (per
    /// Master Design Spec 22.7.5a). Used by SignalRouter to enforce
    /// fire-once semantics.
    var lastPageReachedFiredThisRun: Bool = false

    var order: Int = 0
    var column: Int = 0
    var ganttChartId: UUID?
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    static let maxPages: Int = 99
    static let charLimitPerPage: Int = 400

    init(
        id: UUID = UUID(),
        notation: String = "Note",
        note: String = "",
        pages: [String] = [""],
        currentPageIndex: Int = 0,
        lastPageReachedFiredThisRun: Bool = false,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        // Clamp to allowed page count, default to 1 blank page.
        var ps = pages
        if ps.isEmpty { ps = [""] }
        if ps.count > Self.maxPages { ps = Array(ps.prefix(Self.maxPages)) }
        let clampedPages = ps.map { String($0.prefix(Self.charLimitPerPage)) }
        self.pages = clampedPages
        self.currentPageIndex = max(0, min(clampedPages.count - 1, currentPageIndex))
        self.lastPageReachedFiredThisRun = lastPageReachedFiredThisRun
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }

    /// Whether the currently-displayed page is the last page.
    var isOnLastPage: Bool {
        !pages.isEmpty && currentPageIndex == pages.count - 1
    }
}
