// MARK: - GlyphLCDBrickData
//
// SwiftData @Model for one Glyph LCD module brick.
//
// Locked design from Master Design Spec Part II §19:
//   • 1×4 VERTICAL footprint — column of 4 single-glyph cells.
//   • 4 input ports per LCD module (19.3) — one per glyph slot.
//   • Each slot stores an SF Symbol name OR emoji shortcode
//     (up to 22 chars per 19.3).
//   • LED light-bulb model (19.7): only the most-recently-fired
//     segment "lights up"; the others go dark. Persists until
//     another port fires.

import Foundation
import SwiftData

@Model
final class GlyphLCDBrickData {
    var id: UUID = UUID()
    var notation: String = "Glyph LCD"
    var note: String = ""

    /// The 4 configured glyph identifiers (SF Symbol names like
    /// "sun.max.fill" or emoji like "☀️"). Index = port = cell row.
    var glyphs: [String] = ["sun.max", "moon", "checkmark", "exclamationmark.triangle"]

    /// Runtime state: index of the most-recently-fired port (0-3),
    /// or nil if no port has fired yet. The view lights up that
    /// cell's glyph and dims the others (LED light-bulb model 19.7).
    var currentPortIndex: Int?

    var order: Int = 0
    var column: Int = 0
    var ganttChartId: UUID?
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    static let portCount: Int = 4
    static let charLimit: Int = 22

    init(
        id: UUID = UUID(),
        notation: String = "Glyph LCD",
        note: String = "",
        glyphs: [String] = ["sun.max", "moon", "checkmark", "exclamationmark.triangle"],
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
        var gs = glyphs
        while gs.count < Self.portCount { gs.append("") }
        if gs.count > Self.portCount { gs = Array(gs.prefix(Self.portCount)) }
        self.glyphs = gs
        self.currentPortIndex = currentPortIndex
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
