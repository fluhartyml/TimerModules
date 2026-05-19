// MARK: - GanttCanvasView
//
// The Gantt canvas — 2D grid where bricks live. Scoped to one
// Gantt chart via `chartId`; all @Queries filter by that.
//
// Layout (Michael 2026-05-19 — "the user defines how many
// colums the user needs"):
//   • Vertical axis = rows (`order` field). Lower = higher up.
//   • Horizontal axis = columns (`column` field). 0 = leftmost.
//   • Same row + different columns = sequential (in time).
//   • Different rows + same column = parallel/simultaneous.
//   • Each row has a "+ here" drop zone at its right end so
//     users can add to existing rows.
//   • "+ new row" drop zone at the bottom adds a new row.
//
// M2 wires .timerModule.
// M3 wires the seven boolean logic gates.
// M4 unifies the trace brick.
// M5 wires the nine supplemental types.
// M5.5 adds multi-chart filtering + 2D grid + signal routing
//   + execution log (this file = the chart-filtering + grid).

import SwiftUI
import SwiftData

struct GanttCanvasView: View {
    let chartId: UUID
    let columnCount: Int

    @Environment(\.modelContext) private var modelContext

    @Query private var timers:        [TimerModuleData]
    @Query private var gates:         [GateBrickData]
    @Query private var traces:        [TraceData]
    @Query private var supplementals: [SupplementalBrickData]

    @State private var brickFrames: [UUID: CGRect] = [:]
    @State private var dropTargetedRow: Int? = nil
    @State private var dropTargetedNewRow: Bool = false

    init(chartId: UUID, columnCount: Int) {
        self.chartId = chartId
        self.columnCount = columnCount

        let id = chartId
        _timers = Query(
            filter: #Predicate<TimerModuleData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
        _gates = Query(
            filter: #Predicate<GateBrickData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
        _traces = Query(
            filter: #Predicate<TraceData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
        _supplementals = Query(
            filter: #Predicate<SupplementalBrickData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
    }

    /// Polymorphic wrapper so all brick types can render together
    /// in a single 2D grid render loop.
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

        var row: Int {
            switch self {
            case .timer(let t):        return t.order
            case .gate(let g):         return g.order
            case .trace(let r):        return r.order
            case .supplemental(let s): return s.order
            }
        }

        var column: Int {
            switch self {
            case .timer(let t):        return t.column
            case .gate(let g):         return g.column
            case .trace(let r):        return r.column
            case .supplemental(let s): return s.column
            }
        }
    }

    private var allBricks: [CanvasBrick] {
        let t = timers.map        { CanvasBrick.timer($0) }
        let g = gates.map         { CanvasBrick.gate($0) }
        let r = traces.map        { CanvasBrick.trace($0) }
        let s = supplementals.map { CanvasBrick.supplemental($0) }
        return t + g + r + s
    }

    /// Bricks grouped by row, with each row's bricks sorted by column.
    private var bricksByRow: [(row: Int, bricks: [CanvasBrick])] {
        let grouped = Dictionary(grouping: allBricks, by: \.row)
        return grouped
            .map { (row: $0.key, bricks: $0.value.sorted { $0.column < $1.column }) }
            .sorted { $0.row < $1.row }
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 14) {
                if bricksByRow.isEmpty {
                    emptyCanvasHint
                        .dropDestination(for: BrickType.self) { items, _ in
                            handleDrop(items, targetRow: 0, targetColumn: 0)
                        } isTargeted: { targeted in
                            dropTargetedNewRow = targeted
                        }
                } else {
                    ForEach(bricksByRow, id: \.row) { row in
                        rowContainer(rowIndex: row.row, bricks: row.bricks)
                    }
                }

                addNewRowDropZone
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
            Text("Stack rows vertically for parallel tracks; line bricks up horizontally for sequence.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    dropTargetedNewRow ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
    }

    // MARK: Row container

    private func rowContainer(rowIndex: Int, bricks: [CanvasBrick]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            rowHandle(rowIndex)

            ForEach(bricks) { brick in
                brickContent(for: brick)
                    .reportBrickFrame(id: brick.id)
            }

            addToRowDropZone(rowIndex)

            Spacer(minLength: 0)
        }
    }

    private func rowHandle(_ rowIndex: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(rowIndex + 1)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(.thinMaterial)
                )
            Text("Row")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .padding(.top, 8)
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

    /// Right-side drop zone within a row — drop here to append a
    /// brick to this row in the next column position.
    private func addToRowDropZone(_ rowIndex: Int) -> some View {
        let isTargeted = (dropTargetedRow == rowIndex)
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])
                )
            VStack(spacing: 4) {
                Image(systemName: "plus")
                Text(isTargeted ? "Add to row" : "+")
                    .font(.caption2)
            }
            .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
        }
        .frame(width: 100, height: 200)
        .dropDestination(for: BrickType.self) { items, _ in
            handleDrop(items, targetRow: rowIndex, targetColumn: nextColumn(for: rowIndex))
        } isTargeted: { targeted in
            dropTargetedRow = targeted ? rowIndex : (dropTargetedRow == rowIndex ? nil : dropTargetedRow)
        }
    }

    // MARK: Add-new-row drop zone

    private var addNewRowDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    dropTargetedNewRow ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )

            HStack(spacing: 8) {
                Image(systemName: "plus.rectangle.on.rectangle")
                Text(dropTargetedNewRow ? "Release to add a new row" : "Drop a brick here to add a new row")
                    .font(.subheadline)
            }
            .foregroundStyle(dropTargetedNewRow ? Color.accentColor : .secondary)
        }
        .frame(height: 64)
        .dropDestination(for: BrickType.self) { items, _ in
            handleDrop(items, targetRow: nextAvailableRow(), targetColumn: 0)
        } isTargeted: { targeted in
            dropTargetedNewRow = targeted
        }
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

    private func drawArrow(in ctx: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
        let dx = end.x - start.x
        let controlOffset = max(40, abs(dx) * 0.4)
        let c1 = CGPoint(x: start.x + controlOffset, y: start.y)
        let c2 = CGPoint(x: end.x   - controlOffset, y: end.y)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: c1, control2: c2)
        ctx.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

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
        head.move(to: end); head.addLine(to: h1)
        head.move(to: end); head.addLine(to: h2)
        ctx.stroke(head, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    // MARK: Drop handling

    private func handleDrop(_ items: [BrickType], targetRow: Int, targetColumn: Int) -> Bool {
        guard let type = items.first else { return false }
        guard type.isWiredUp else { return false }

        let row = targetRow
        let column = targetColumn

        switch type {
        case .timerModule:
            let new = TimerModuleData(
                notation: "Timer \(row + 1).\(column + 1)",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate:
            let new = GateBrickData(
                gateType: type,
                order: row,
                column: column,
                ganttChartId: chartId,
                notation: ""
            )
            modelContext.insert(new)
            return true

        case .trace:
            let new = TraceData(
                traceType: .fsEdge,
                order: row,
                column: column,
                ganttChartId: chartId,
                notation: ""
            )
            modelContext.insert(new)
            return true

        case .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            return false  // not palette tiles

        case .note, .marker, .trigger, .action,
             .group, .variable, .webhook,
             .conditional, .loop:
            let new = SupplementalBrickData(
                brickType: type,
                order: row,
                column: column,
                ganttChartId: chartId,
                notation: ""
            )
            modelContext.insert(new)
            return true
        }
    }

    /// Next row index after the highest existing row in this chart.
    private func nextAvailableRow() -> Int {
        let maxRow = allBricks.map(\.row).max() ?? -1
        return maxRow + 1
    }

    /// Next column index after the highest existing column in the
    /// given row in this chart.
    private func nextColumn(for row: Int) -> Int {
        let inRow = allBricks.filter { $0.row == row }
        let maxCol = inRow.map(\.column).max() ?? -1
        return maxCol + 1
    }
}
