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
    case calendarProcessing  // 2026-05-22 — Calendar Processing Module (CPM). 4×4 calendar-aware fan-out with up to 52 numbered output ports + bidirectional EventKit bridge. Spec: TimerModules-Brain-Module-Refinement-2026-05-22.html.
    case start    // 2026-05-21 — program entry module (Part I §2). Exactly one per chart, one-shot per run, re-arms on program termination. NOT to be confused with Trigger.
    case delay    // 2026-05-21 — 1×1 cascade-spacing waypoint (Part II §18). Display 0-9 = ten seconds max per module. Compose in series for longer waits. 7-segment crosswalk countdown when in flight.
    case textLCD  // 2026-05-21 — 4×1 horizontal runtime output (Part II §19). 4 input ports, each with a 22-char canned message; persistent e-ink display.
    case glyphLCD // 2026-05-21 — 1×4 vertical runtime output (Part II §19). 4 input ports, each with a glyph; LED light-bulb model (one lit at a time).
    case digitalClock  // 2026-05-21 — 2×1 horizontal passive readout (Part II §12). Current system time HH:MM. No trace I/O in v1.0.
    case calendarDate  // 2026-05-21 — 2×1 horizontal passive readout (Part II §12.10). Current system date. No trace I/O in v1.0.
    case battery       // 2026-05-21 — 1×1 passive readout (Part II §12.11). Battery % on iOS/iPad. Mac variant: shakedown.
    case noteModule    // 2026-05-21 — 4×4 quasi-passive canvas annotation (Part II §22.7). Smart Stack of swipable pages; fires output when user reaches last page.
    case weather       // 2026-05-21 — 2×1 passive readout (Part II §12.12). Icon + temp via WeatherKit. Entitlement risk flagged at 12.13.

    // Logic-gate connectors
    case andGate
    case orGate
    case notGate
    case norGate
    case nandGate
    case xorGate
    case xnorGate

    // Connector — unified trace (the single "wire" brick).
    // Per Michael 2026-05-19: "a trace being an adjustable wire you
    // can wire from any module to another module." Replaces the six
    // separate FS/SS/FF/SF/Lag-Lead/Splitter tiles in the palette.
    // The trace's RELATIONSHIP TYPE (FS / SS / FF / SF) is set on
    // the trace's row UI, not by which tile you dragged.
    case trace

    // PM-dependency RELATIONSHIP TYPES (no longer separate palette
    // tiles — they live as values the unified `.trace` brick can be
    // configured to use). Kept as BrickType cases so existing
    // TraceData rows that store one as `traceTypeRaw` continue to
    // resolve correctly.
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
    case endBrick    // M5.7 — terminates the program when reached

    var id: String { rawValue }

    /// Family this brick belongs to — used for grouping in the palette.
    enum Family: String, CaseIterable {
        case functional
        case logicGate
        case connector
        case supplemental

        var displayName: String {
            switch self {
            case .functional:     return "Functional"
            case .logicGate:      return "Logic gates"
            case .connector:      return "Connectors"
            case .supplemental:   return "Supplemental"
            }
        }
    }

    var family: Family {
        switch self {
        case .timerModule, .calendarProcessing, .start, .delay, .textLCD, .glyphLCD, .digitalClock, .calendarDate, .battery, .noteModule, .weather:
            return .functional
        case .andGate, .orGate, .notGate, .norGate, .nandGate, .xorGate, .xnorGate:
            return .logicGate
        case .trace, .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            return .connector
        case .note, .marker, .trigger, .action, .group, .variable, .webhook, .conditional, .loop, .endBrick:
            return .supplemental
        }
    }

    /// Whether this brick appears in the user-facing palette.
    /// The unified `.trace` brick is the only Connector palette tile;
    /// the FS/SS/FF/SF/lagLead/splitter cases are internal values
    /// the trace can be configured to use, not separate tiles.
    var appearsInPalette: Bool {
        switch self {
        case .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            return false
        default:
            return true
        }
    }

    /// Short label shown on the palette tile.
    var displayName: String {
        switch self {
        case .timerModule:         return "Timer"
        case .calendarProcessing:  return "CPM"
        case .start:        return "Trigger"
        case .delay:        return "Delay"
        case .textLCD:      return "Text LCD"
        case .glyphLCD:     return "Glyph LCD"
        case .digitalClock: return "Clock"
        case .calendarDate: return "Date"
        case .battery:      return "Battery"
        case .noteModule:   return "Note"
        case .weather:      return "Weather"
        case .andGate:      return "AND"
        case .orGate:       return "OR"
        case .notGate:      return "NOT"
        case .norGate:      return "NOR"
        case .nandGate:     return "NAND"
        case .xorGate:      return "XOR"
        case .xnorGate:     return "XNOR"
        case .trace:        return "Trace"
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
        case .endBrick:     return "End"
        }
    }

    /// SF Symbol for the palette tile. Returns nil for brick types
    /// that use a mathematical-operator text glyph instead (logic
    /// gates) — see `textGlyph`.
    var symbolName: String? {
        switch self {
        case .timerModule:        return "timer"
        case .calendarProcessing: return "brain"
        case .start:        return "circle.fill"
        case .delay:        return "hourglass"
        case .textLCD:      return "text.viewfinder"
        case .glyphLCD:     return "square.grid.4x3.fill"
        case .digitalClock: return "clock"
        case .calendarDate: return "calendar"
        case .battery:      return "battery.50"
        case .noteModule:   return "doc.text"
        case .weather:      return "cloud.sun"
        case .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate:
            return nil  // uses textGlyph
        case .trace:        return "point.topleft.down.curvedto.point.bottomright.up"
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
        case .endBrick:     return "stop.circle.fill"
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
    /// M4 unifies the trace brick (.trace) — internal type values
    /// (fsEdge etc.) remain as configurable values; M5 flips the
    /// nine supplemental types.
    var isWiredUp: Bool {
        switch self {
        case .timerModule, .calendarProcessing, .start, .delay, .textLCD, .glyphLCD, .digitalClock, .calendarDate, .battery, .noteModule, .weather,
             .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate,
             .trace,
             .fsEdge, .ssEdge, .ffEdge, .sfEdge,
             .lagLead, .splitter,
             .note, .marker, .trigger, .action,
             .group, .variable, .webhook,
             .conditional, .loop, .endBrick:
            return true
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
