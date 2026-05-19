// MARK: - BrickType
//
// Discriminator for what kind of brick a user is dragging out of the
// palette. Conforms to Transferable so SwiftUI's .draggable() /
// .dropDestination() can shuttle a value across the drag.
//
// v1.0 brick families (per roadmap Section 1.5):
//   • Functional:   .timerModule
//   • Connectors — logic gates: .and .or .not .nor .nand .xor .xnor
//   • Connectors — PM types:    .fs .ss .ff .sf .lagLead .splitter
//   • Supplemental: .note .marker .trigger .action .group .variable
//                   .webhook .conditional .loop
//
// M2 wires only .timerModule end-to-end. M3 adds gate handling,
// M4 adds PM types, M5 adds supplemental — but the enum carries
// all cases up front so the palette can show the full inventory
// from day one.

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

enum BrickType: String, Codable, CaseIterable, Identifiable, Transferable {
    // Functional
    case timerModule

    // Logic-gate connectors
    case andGate
    case orGate
    case notGate
    case norGate
    case nandGate
    case xorGate
    case xnorGate

    // PM-dependency connectors
    case fsEdge
    case ssEdge
    case ffEdge
    case sfEdge
    case lagLead
    case splitter

    // Supplemental
    case note
    case marker
    case trigger
    case action
    case group
    case variable
    case webhook
    case conditional
    case loop

    var id: String { rawValue }

    /// Family this brick belongs to — used for grouping in the palette.
    enum Family: String, CaseIterable {
        case functional
        case logicGate
        case pmDependency
        case supplemental

        var displayName: String {
            switch self {
            case .functional:     return "Functional"
            case .logicGate:      return "Logic gates"
            case .pmDependency:   return "PM dependencies"
            case .supplemental:   return "Supplemental"
            }
        }
    }

    var family: Family {
        switch self {
        case .timerModule:
            return .functional
        case .andGate, .orGate, .notGate, .norGate, .nandGate, .xorGate, .xnorGate:
            return .logicGate
        case .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            return .pmDependency
        case .note, .marker, .trigger, .action, .group, .variable, .webhook, .conditional, .loop:
            return .supplemental
        }
    }

    /// Short label shown on the palette tile.
    var displayName: String {
        switch self {
        case .timerModule:  return "Timer"
        case .andGate:      return "AND"
        case .orGate:       return "OR"
        case .notGate:      return "NOT"
        case .norGate:      return "NOR"
        case .nandGate:     return "NAND"
        case .xorGate:      return "XOR"
        case .xnorGate:     return "XNOR"
        case .fsEdge:       return "FS"
        case .ssEdge:       return "SS"
        case .ffEdge:       return "FF"
        case .sfEdge:       return "SF"
        case .lagLead:      return "Lag/Lead"
        case .splitter:     return "Splitter"
        case .note:         return "Note"
        case .marker:       return "Marker"
        case .trigger:      return "Trigger"
        case .action:       return "Action"
        case .group:        return "Group"
        case .variable:     return "Variable"
        case .webhook:      return "Webhook"
        case .conditional:  return "If/Else"
        case .loop:         return "Loop"
        }
    }

    /// SF Symbol for the palette tile. Returns nil for brick types
    /// that use a mathematical-operator text glyph instead (logic
    /// gates) — see `textGlyph`.
    var symbolName: String? {
        switch self {
        case .timerModule:  return "timer"
        case .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate:
            return nil  // uses textGlyph
        case .fsEdge, .ssEdge, .ffEdge, .sfEdge:
            return "arrow.right"
        case .lagLead:      return "arrow.left.arrow.right"
        case .splitter:     return "arrow.triangle.branch"
        case .note:         return "note.text"
        case .marker:       return "diamond"
        case .trigger:      return "play.circle"
        case .action:       return "bolt"
        case .group:        return "square.dashed"
        case .variable:     return "number"
        case .webhook:      return "network"
        case .conditional:  return "questionmark.diamond"
        case .loop:         return "arrow.clockwise"
        }
    }

    /// Boolean-operator text glyph for the logic-gate bricks.
    /// Returns nil for non-gate bricks (which use `symbolName`).
    var textGlyph: String? {
        switch self {
        case .andGate:   return "∧"   // logical AND
        case .orGate:    return "∨"   // logical OR
        case .notGate:   return "¬"   // logical NOT
        case .norGate:   return "↓"   // Peirce arrow (NOR)
        case .nandGate:  return "⊼"   // Sheffer stroke (NAND)
        case .xorGate:   return "⊕"   // exclusive OR
        case .xnorGate:  return "⊙"   // XNOR
        default:         return nil
        }
    }

    /// Whether this brick type is fully wired up in v1.0 of the build.
    /// M2 wires .timerModule; M3 flips the seven boolean logic gates;
    /// M4 flips the six PM-dependency types; M5 flips supplemental.
    var isWiredUp: Bool {
        switch self {
        case .timerModule,
             .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate,
             .fsEdge, .ssEdge, .ffEdge, .sfEdge,
             .lagLead, .splitter:
            return true
        default:
            return false
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
