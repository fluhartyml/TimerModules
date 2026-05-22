// MARK: - SupplementalBrickData
//
// SwiftData @Model covering all nine supplemental brick types
// from the v1.0 palette (per roadmap Section 1.5.3):
//   .note .marker .trigger .action .group .variable
//   .webhook .conditional .loop
//
// Each brick type uses a different subset of the fields below.
// SupplementalBrickView dispatches on `brickType` to render the
// appropriate config UI.

import Foundation
import SwiftData

@Model
final class SupplementalBrickData {
    var id: UUID = UUID()

    /// Which BrickType this is. Must be one of the nine
    /// supplemental cases.
    var brickTypeRaw: String = ""

    /// Row on the Gantt canvas (vertical position; lower = higher up).
    var order: Int = 0

    /// Column on the Gantt canvas (horizontal position within the row).
    var column: Int = 0

    /// Which saved Gantt chart this brick belongs to.
    var ganttChartId: UUID?

    /// User-editable label across all supplemental types.
    var notation: String = ""

    /// User's free-form note about this module (Michael 2026-05-20).
    /// Edited via the note.text glyph button in the card's top-right
    /// corner or the long-press / right-click context menu.
    var note: String = ""

    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    // MARK: Type-specific fields (most are nil/empty per type)

    /// Note: the body text.
    /// Trigger: the label shown on the Start button.
    /// Conditional: the condition expression.
    var textContent: String = ""

    /// Action: action kind raw — "sound" / "notification" / "log" / "link".
    /// Trigger: trigger kind raw — "manual" / "scheduled" / "external".
    /// Webhook: HTTP method — "GET" / "POST" / "PUT" / "DELETE".
    var kindRaw: String = ""

    /// Action / Trigger: per-kind config string (sound name, deep-link URL,
    /// schedule cron, etc.).
    /// Webhook: target URL.
    var configString: String = ""

    /// Webhook: optional request body (JSON or form-encoded).
    var bodyContent: String = ""

    /// Marker: hex color string for the diamond.
    var markerColorHex: String = "#FFB000"

    /// Variable: current numeric value of the counter.
    var variableValue: Double = 0

    /// Variable: initial value to reset to.
    var variableInitial: Double = 0

    /// Loop: total iterations to run (Int).
    var loopCount: Int = 1

    /// Loop: current iteration counter at run time.
    var loopCurrentIteration: Int = 0

    /// Group / Conditional / Loop: ids of bricks contained / branched-into
    /// / iterated over. Conditional uses index 0 for the true branch and
    /// index 1+ for the false branch (separated by a sentinel — see
    /// `conditionalTrueIds` / `conditionalFalseIds` computed properties).
    var containedBrickIds: [UUID] = []

    /// Conditional: false-branch brick ids stored separately so the
    /// true/false branches don't tangle.
    var alternateBrickIds: [UUID] = []

    init(
        id: UUID = UUID(),
        brickType: BrickType,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        notation: String = "",
        textContent: String = "",
        kindRaw: String = "",
        configString: String = "",
        bodyContent: String = "",
        markerColorHex: String = "#FFB000",
        variableValue: Double = 0,
        variableInitial: Double = 0,
        loopCount: Int = 1,
        loopCurrentIteration: Int = 0,
        containedBrickIds: [UUID] = [],
        alternateBrickIds: [UUID] = [],
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.brickTypeRaw = brickType.rawValue
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.notation = notation
        self.textContent = textContent
        self.kindRaw = kindRaw
        self.configString = configString
        self.bodyContent = bodyContent
        self.markerColorHex = markerColorHex
        self.variableValue = variableValue
        self.variableInitial = variableInitial
        self.loopCount = loopCount
        self.loopCurrentIteration = loopCurrentIteration
        self.containedBrickIds = containedBrickIds
        self.alternateBrickIds = alternateBrickIds
        self.createdDate = createdDate
        self.updatedDate = updatedDate

        // Sensible defaults per type
        if kindRaw.isEmpty {
            switch brickType {
            case .trigger:  self.kindRaw = "manual"
            case .action:   self.kindRaw = "log"
            case .webhook:  self.kindRaw = "POST"
            default:        break
            }
        }
    }

    var brickType: BrickType {
        BrickType(rawValue: brickTypeRaw) ?? .note
    }
}
