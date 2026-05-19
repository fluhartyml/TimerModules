// MARK: - GateBrickData
//
// SwiftData @Model for one logic-gate brick on the Gantt canvas.
// One GateBrickData = one snap-together gate instance (AND, OR,
// NOT, NOR, NAND, XOR, or XNOR).
//
// The gate's boolean logic is implemented here as `evaluate(inputs:)`.
// Wiring (which Timer/gate bricks feed inputs in, and where the
// output goes) lives on the upcoming TraceData entity (M4) — at
// M3 the gate is a standalone canvas element with its evaluation
// rule ready to use.

import Foundation
import SwiftData

@Model
final class GateBrickData {
    /// Stable identifier — used by traces (M4) to reference this gate.
    var id: UUID

    /// Stores BrickType.rawValue. Constrained to the seven boolean
    /// gate cases (.andGate, .orGate, .notGate, .norGate, .nandGate,
    /// .xorGate, .xnorGate). Stored as String so SwiftData can persist
    /// it without needing a custom transformer.
    var gateTypeRaw: String

    /// Row position on the Gantt canvas. Lower = higher row.
    /// Shared sort key with TimerModuleData so bricks can interleave.
    var order: Int

    /// Optional user notation — gate brick can be labeled like timers.
    var notation: String

    /// Bookkeeping.
    var createdDate: Date
    var updatedDate: Date

    init(
        id: UUID = UUID(),
        gateType: BrickType,
        order: Int = 0,
        notation: String = "",
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.gateTypeRaw = gateType.rawValue
        self.order = order
        self.notation = notation
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }

    /// Convenience accessor — returns the BrickType case for this gate.
    var gateType: BrickType {
        BrickType(rawValue: gateTypeRaw) ?? .andGate
    }

    /// Evaluates the gate's boolean logic against a set of input
    /// completion signals. Pure function: same inputs → same output.
    ///
    /// Semantics for N-input cases:
    ///   • AND  — all inputs true (false on empty input list)
    ///   • OR   — any input true
    ///   • NOT  — inverts the first input (single-input gate by spec)
    ///   • NOR  — none of the inputs true
    ///   • NAND — not all inputs true
    ///   • XOR  — exactly one input true
    ///   • XNOR — all inputs the same (all true OR all false)
    func evaluate(inputs: [Bool]) -> Bool {
        switch gateType {
        case .andGate:
            return !inputs.isEmpty && inputs.allSatisfy { $0 }
        case .orGate:
            return inputs.contains(true)
        case .notGate:
            return !(inputs.first ?? false)
        case .norGate:
            return !inputs.contains(true)
        case .nandGate:
            return !inputs.allSatisfy { $0 }
        case .xorGate:
            return inputs.filter { $0 }.count == 1
        case .xnorGate:
            return inputs.allSatisfy { $0 } || inputs.allSatisfy { !$0 }
        default:
            // gateTypeRaw should never reach here — guard anyway.
            return false
        }
    }
}
