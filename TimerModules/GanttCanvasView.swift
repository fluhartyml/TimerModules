// MARK: - GanttCanvasView
//
// The Gantt canvas — vertical list of rows where bricks live.
// Drop a brick from BrickPaletteView onto the canvas or its
// add-row drop zone to create a new instance. Timer, gate, and
// trace bricks interleave on the canvas by their `order` field.
//
// M2 wires .timerModule.
// M3 wires the seven boolean logic gates.
// M4 wires the six PM-dependency traces (FS/SS/FF/SF/Lag-Lead/
//   Splitter) AND draws edge arrows between source/destination
//   brick positions via an overlay layer.
// M5 wires supplemental bricks.

import SwiftUI
import SwiftData

struct GanttCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerModuleData.order)       private var timers:        [TimerModuleData]
    @Query(sort: \GateBrickData.order)         private var gates:         [GateBrickData]
    @Query(sort: \TraceData.order)             private var traces:        [TraceData]
    @Query(sort: \SupplementalBrickData.order) private var supplementals: [SupplementalBrickData]

    @State private var isDropTargeted: Bool = false
    @State private var brickFrames: [UUID: CGRect] = [:]

    /// Polymorphic wrapper so all brick types can interleave in a
    /// single ordered render loop.
    private enum CanvasBrick: Identifiable {
        case timer(TimerModuleData)
        case gate(GateBrickData)
        case trace(TraceData)
        case supplemental(SupplementalBrickData)

        var id: UUID {
            switch self {
            case .timer(let t):        return t.id
            case .gate(let g):         return g.id
            case .trace(let r):        return r.id
            case .supplemental(let s): return s.id
            }
        }

        var order: Int {
            switch self {
            case .timer(let t):        return t.order
            case .gate(let g):         return g.order
            case .trace(let r):        return r.order
            case .supplemental(let s): return s.order
            }
        }
    }

    private var canvasBricks: [CanvasBrick] {
        let t = timers.map        { CanvasBrick.timer($0) }
        let g = gates.map         { CanvasBrick.gate($0) }
        let r = traces.map        { CanvasBrick.trace($0) }
        let s = supplementals.map { CanvasBrick.supplemental($0) }
        return (t + g + r + s).sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if canvasBricks.isEmpty {
                    emptyCanvasHint
                        .dropDestination(for: BrickType.self) { items, _ in
                            handleDrop(items)
                        } isTargeted: { targeted in
                            isDropTargeted = targeted
                        }
                } else {
                    ForEach(canvasBricks) { brick in
                        canvasRow(for: brick)
                    }
                }

                addRowDropZone
                    .dropDestination(for: BrickType.self) { items, _ in
                        handleDrop(items)
                    } isTargeted: { targeted in
                        isDropTargeted = targeted
                    }
            }
            .padding(20)
        }
        .coordinateSpace(name: "ganttCanvas")
        .overlay(alignment: .topLeading) {
            traceEdgeOverlay
                .allowsHitTesting(false)
        }
        .onPreferenceChange(BrickFramePreferenceKey.self) { newValue in
            brickFrames = newValue
        }
        .background(canvasBackground)
    }

    // MARK: Background

    private var canvasBackground: some View {
        Color.gray.opacity(0.06)
    }

    // MARK: Empty state

    private var emptyCanvasHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Drag a brick here to start your Gantt")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Try a Timer, a logic gate, or a PM trace from the palette above.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
    }

    // MARK: Polymorphic canvas row

    @ViewBuilder
    private func canvasRow(for brick: CanvasBrick) -> some View {
        HStack(alignment: .top, spacing: 12) {
            rowHandle(for: brick)
            brickContent(for: brick)
                .reportBrickFrame(id: brick.id)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func brickContent(for brick: CanvasBrick) -> some View {
        switch brick {
        case .timer(let timer):
            TimerModuleBrickView(data: timer)
        case .gate(let gate):
            GateBrickView(data: gate)
        case .trace(let trace):
            TraceBrickView(
                data: trace,
                timerCandidates: timers,
                gateCandidates: gates
            )
        case .supplemental(let sup):
            SupplementalBrickView(data: sup)
        }
    }

    /// Row handle on the left with the row number and a delete affordance.
    private func rowHandle(for brick: CanvasBrick) -> some View {
        VStack(spacing: 6) {
            Text("\(brick.order + 1)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(.thinMaterial)
                )

            Button {
                delete(brick)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .tint(.red)
            .help("Delete this row")
        }
        .padding(.top, 8)
    }

    private func delete(_ brick: CanvasBrick) {
        switch brick {
        case .timer(let t):        modelContext.delete(t)
        case .gate(let g):         modelContext.delete(g)
        case .trace(let r):        modelContext.delete(r)
        case .supplemental(let s): modelContext.delete(s)
        }
    }

    // MARK: Add-row drop zone

    private var addRowDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )

            HStack(spacing: 8) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                Text(isDropTargeted ? "Release to add brick" : "Drop a brick here to add a new row")
                    .font(.subheadline)
                    .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
            }
        }
        .frame(height: 64)
    }

    // MARK: Trace edge overlay

    @ViewBuilder
    private var traceEdgeOverlay: some View {
        Canvas { ctx, size in
            for trace in traces where trace.isWired {
                guard let srcId = trace.sourceBrickId,
                      let srcFrame = brickFrames[srcId] else { continue }

                let srcPoint = anchorPoint(of: srcFrame, side: trace.sourceAnchor)

                for destId in trace.destinationBrickIds {
                    guard let destFrame = brickFrames[destId] else { continue }
                    let destPoint = anchorPoint(of: destFrame, side: trace.destinationAnchor)

                    drawArrow(in: ctx, from: srcPoint, to: destPoint, color: edgeColor(for: trace))
                }
            }
        }
    }

    private func anchorPoint(of frame: CGRect, side: TraceAnchor) -> CGPoint {
        switch side {
        case .start:  return CGPoint(x: frame.minX, y: frame.midY)
        case .finish: return CGPoint(x: frame.maxX, y: frame.midY)
        }
    }

    private func edgeColor(for trace: TraceData) -> Color {
        switch trace.traceType {
        case .fsEdge, .ssEdge, .ffEdge, .sfEdge: return .blue
        case .lagLead:                            return .purple
        case .splitter:                           return .teal
        default:                                  return .gray
        }
    }

    /// Draws a Bezier curve with an arrowhead from `start` to `end`.
    private func drawArrow(in ctx: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
        let dx = end.x - start.x
        let controlOffset = max(40, abs(dx) * 0.4)
        let c1 = CGPoint(x: start.x + controlOffset, y: start.y)
        let c2 = CGPoint(x: end.x   - controlOffset, y: end.y)

        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: c1, control2: c2)
        ctx.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Arrowhead at end
        let theta: CGFloat = .pi / 7
        let headLength: CGFloat = 10
        let angle = atan2(end.y - c2.y, end.x - c2.x)

        let h1 = CGPoint(
            x: end.x - headLength * cos(angle - theta),
            y: end.y - headLength * sin(angle - theta)
        )
        let h2 = CGPoint(
            x: end.x - headLength * cos(angle + theta),
            y: end.y - headLength * sin(angle + theta)
        )

        var head = Path()
        head.move(to: end)
        head.addLine(to: h1)
        head.move(to: end)
        head.addLine(to: h2)
        ctx.stroke(head, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    // MARK: Drop handling

    private func handleDrop(_ items: [BrickType]) -> Bool {
        guard let type = items.first else { return false }
        guard type.isWiredUp else { return false }

        let nextOrder = nextAvailableOrder()

        switch type {
        case .timerModule:
            let new = TimerModuleData(
                notation: "Timer \(nextOrder + 1)",
                order: nextOrder
            )
            modelContext.insert(new)
            return true

        case .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate:
            let new = GateBrickData(
                gateType: type,
                order: nextOrder,
                notation: ""
            )
            modelContext.insert(new)
            return true

        case .trace:
            // Unified trace brick — default to FS (most common Gantt
            // edge); user adjusts type, source, destinations, lag on
            // the trace row's pickers.
            let new = TraceData(
                traceType: .fsEdge,
                order: nextOrder,
                notation: ""
            )
            modelContext.insert(new)
            return true

        case .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            // Internal trace-type values, not palette tiles. Should
            // not reach here from a drag because appearsInPalette is
            // false for these. Guard anyway.
            return false

        case .note, .marker, .trigger, .action,
             .group, .variable, .webhook,
             .conditional, .loop:
            let new = SupplementalBrickData(
                brickType: type,
                order: nextOrder,
                notation: ""
            )
            modelContext.insert(new)
            return true
        }
    }

    private func nextAvailableOrder() -> Int {
        let highestTimer        = timers.map(\.order).max() ?? -1
        let highestGate         = gates.map(\.order).max() ?? -1
        let highestTrace        = traces.map(\.order).max() ?? -1
        let highestSupplemental = supplementals.map(\.order).max() ?? -1
        return max(highestTimer, highestGate, highestTrace, highestSupplemental) + 1
    }
}
