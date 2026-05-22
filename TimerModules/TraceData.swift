// MARK: - TraceData
//
// SwiftData @Model for one PM-dependency trace on the Gantt canvas.
// A trace is the edge that links a source brick's event (start or
// finish) to a destination brick's event (start or finish). The
// trace type determines which events are linked:
//
//   FS  — Finish-to-Start   (source.finish → destination.start)
//   SS  — Start-to-Start    (source.start  → destination.start)
//   FF  — Finish-to-Finish  (source.finish → destination.finish)
//   SF  — Start-to-Finish   (source.start  → destination.finish)
//   Lag/Lead — generic edge with a non-zero offset (lagSeconds)
//   Splitter — one source fanning out to multiple destinations
//
// A trace is both a configurable "brick" (visible as a row on the
// canvas, with source/destination pickers) AND a visual edge
// (drawn as an arrow between bricks on the canvas overlay).

import Foundation
import SwiftData

@Model
final class TraceData {
    var id: UUID = UUID()

    /// Stores BrickType.rawValue. Must be one of the six PM-dependency
    /// cases (.fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter).
    var traceTypeRaw: String = ""

    /// The upstream brick's id. nil until the user picks a source.
    var sourceBrickId: UUID?

    /// Downstream brick ids. Length 1 for FS/SS/FF/SF/lagLead, length 1+
    /// for splitter. Empty until the user picks at least one destination.
    var destinationBrickIds: [UUID] = []

    /// Offset in seconds applied to the trace's trigger event. Positive
    /// = downstream event happens N seconds AFTER the trigger (lag).
    /// Negative = downstream event happens N seconds BEFORE (lead).
    var lagSeconds: TimeInterval = 0

    /// Row on the Gantt canvas (vertical position; lower = higher up).
    var order: Int = 0

    /// Column on the Gantt canvas (horizontal position within the row).
    var column: Int = 0

    /// Which saved Gantt chart this trace belongs to.
    var ganttChartId: UUID?

    /// Optional user notation.
    var notation: String = ""

    /// Optional port index on the destination module. Used by
    /// multi-input modules (Text LCD, Glyph LCD, Status) per
    /// Master Design Spec 16.1 — port-per-output-state addressing.
    /// 0-indexed (0 = first port). Default 0; for non-multi-input
    /// destinations the field is ignored.
    var destinationPortIndex: Int = 0

    /// Bookkeeping.
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        traceType: BrickType,
        sourceBrickId: UUID? = nil,
        destinationBrickIds: [UUID] = [],
        lagSeconds: TimeInterval = 0,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        notation: String = "",
        destinationPortIndex: Int = 0,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.traceTypeRaw = traceType.rawValue
        self.sourceBrickId = sourceBrickId
        self.destinationBrickIds = destinationBrickIds
        self.lagSeconds = lagSeconds
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.notation = notation
        self.destinationPortIndex = destinationPortIndex
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }

    /// Convenience accessor — returns the BrickType case for this trace.
    var traceType: BrickType {
        BrickType(rawValue: traceTypeRaw) ?? .fsEdge
    }

    /// True once both ends of the trace are configured (source + at
    /// least one destination). Used by the canvas overlay to decide
    /// whether to draw the edge.
    var isWired: Bool {
        sourceBrickId != nil && !destinationBrickIds.isEmpty
    }

    /// Which side of the source brick to start the edge from.
    /// FS / FF: finish side (right edge of source bar).
    /// SS / SF / lagLead / splitter: start side (left edge of source bar).
    var sourceAnchor: TraceAnchor {
        switch traceType {
        case .fsEdge, .ffEdge:                          return .finish
        case .ssEdge, .sfEdge, .lagLead, .splitter:     return .start
        default:                                        return .finish
        }
    }

    /// Which side of the destination brick to end the edge at.
    /// FS / SS / lagLead / splitter: start side of destination.
    /// FF / SF: finish side of destination.
    var destinationAnchor: TraceAnchor {
        switch traceType {
        case .fsEdge, .ssEdge, .lagLead, .splitter:     return .start
        case .ffEdge, .sfEdge:                          return .finish
        default:                                        return .start
        }
    }
}

/// Which side of a brick a trace anchors to — start (left) or
/// finish (right). Used by the canvas overlay to position the
/// arrow endpoints.
enum TraceAnchor {
    case start
    case finish
}
