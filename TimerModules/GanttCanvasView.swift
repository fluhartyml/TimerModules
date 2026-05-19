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

    /// Shared tap-to-wire coordinator with BrickPaletteView (M5.7).
    /// When wiring.isWiring is true, bricks become tappable for
    /// source/destination selection instead of operating normally.
    @Bindable var wiring: WiringState

    @Environment(\.modelContext) private var modelContext

    @Query private var timers:        [TimerModuleData]
    @Query private var gates:         [GateBrickData]
    @Query private var traces:        [TraceData]
    @Query private var supplementals: [SupplementalBrickData]

    @State private var brickFrames: [UUID: CGRect] = [:]
    @State private var dropTargetedRow: Int? = nil
    @State private var dropTargetedNewRow: Bool = false

    init(chartId: UUID, columnCount: Int, wiring: WiringState) {
        self.chartId = chartId
        self.columnCount = columnCount
        self.wiring = wiring

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

    /// Polymorphic wrapper so renderable bricks can share a render
    /// loop. Per M5.7 (Michael 2026-05-19), traces no longer render
    /// as rows — they live purely as overlay edges drawn between
    /// brick frames in `traceEdgeOverlay`. Only Timer, Gate, and
    /// Supplemental bricks render in the grid.
    private enum CanvasBrick: Identifiable {
        case timer(TimerModuleData)
        case gate(GateBrickData)
        case supplemental(SupplementalBrickData)

        var id: UUID {
            switch self {
            case .timer(let t):        return t.id
            case .gate(let g):         return g.id
            case .supplemental(let s): return s.id
            }
        }

        var row: Int {
            switch self {
            case .timer(let t):        return t.order
            case .gate(let g):         return g.order
            case .supplemental(let s): return s.order
            }
        }

        var column: Int {
            switch self {
            case .timer(let t):        return t.column
            case .gate(let g):         return g.column
            case .supplemental(let s): return s.column
            }
        }
    }

    private var allBricks: [CanvasBrick] {
        let t = timers.map        { CanvasBrick.timer($0) }
        let g = gates.map         { CanvasBrick.gate($0) }
        let s = supplementals.map { CanvasBrick.supplemental($0) }
        return t + g + s
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
            Text("Drag a brick here to start your Timer Module")
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
                .wiringOverlay(id: timer.id, wiring: wiring) { tappedBrick(timer.id) }
                .contextMenu { deleteMenuItem(for: brick) }
        case .gate(let gate):
            GateBrickView(data: gate)
                .wiringOverlay(id: gate.id, wiring: wiring) { tappedBrick(gate.id) }
                .contextMenu { deleteMenuItem(for: brick) }
        case .supplemental(let sup):
            SupplementalBrickView(data: sup)
                .wiringOverlay(id: sup.id, wiring: wiring) { tappedBrick(sup.id) }
                .contextMenu { deleteMenuItem(for: brick) }
        }
    }

    /// Right-click / long-press context menu items for a card.
    /// Includes Move Up/Down/Left/Right + Delete (Michael caught
    /// both the missing delete and missing move 2026-05-19).
    @ViewBuilder
    private func deleteMenuItem(for brick: CanvasBrick) -> some View {
        Button {
            move(brick, by: (-1, 0))  // row up
        } label: {
            Label("Move up a row", systemImage: "arrow.up")
        }
        Button {
            move(brick, by: (1, 0))   // row down
        } label: {
            Label("Move down a row", systemImage: "arrow.down")
        }
        Button {
            move(brick, by: (0, -1))  // column left
        } label: {
            Label("Move left a column", systemImage: "arrow.left")
        }
        Button {
            move(brick, by: (0, 1))   // column right
        } label: {
            Label("Move right a column", systemImage: "arrow.right")
        }
        Divider()
        Button(role: .destructive) {
            deleteCanvasBrick(brick)
        } label: {
            Label("Delete card", systemImage: "trash")
        }
    }

    /// Polymorphic move — adjusts a card's `order` (row) and
    /// `column` by the given delta. Bottom-clamped to 0 so cards
    /// can't move to negative positions.
    private func move(_ brick: CanvasBrick, by delta: (row: Int, column: Int)) {
        switch brick {
        case .timer(let t):
            t.order = max(0, t.order + delta.row)
            t.column = max(0, t.column + delta.column)
            t.updatedDate = Date()
        case .gate(let g):
            g.order = max(0, g.order + delta.row)
            g.column = max(0, g.column + delta.column)
            g.updatedDate = Date()
        case .supplemental(let s):
            s.order = max(0, s.order + delta.row)
            s.column = max(0, s.column + delta.column)
            s.updatedDate = Date()
        }
    }

    /// Polymorphic delete across all brick families.
    private func deleteCanvasBrick(_ brick: CanvasBrick) {
        switch brick {
        case .timer(let t):        modelContext.delete(t)
        case .gate(let g):         modelContext.delete(g)
        case .supplemental(let s): modelContext.delete(s)
        }
    }

    /// Called when a brick is tapped while the canvas is in wiring
    /// mode. Drives the tap-to-wire state machine: first tap picks
    /// the source, second tap creates the wire to that destination.
    private func tappedBrick(_ brickId: UUID) {
        guard wiring.isWiring else { return }
        switch wiring.mode {
        case .idle:
            return
        case .awaitingSource:
            wiring.pickedSource(brickId)
        case .awaitingDestination:
            if let sourceId = wiring.pickedDestination(brickId) {
                createWire(from: sourceId, to: brickId)
            }
        }
    }

    /// Create a TraceData connecting the two bricks via the
    /// tap-to-wire flow. Default to FS (Finish → Start) with no
    /// lag; the user adjusts via the trace's popover (future).
    private func createWire(from sourceId: UUID, to destId: UUID) {
        let new = TraceData(
            traceType: .fsEdge,
            sourceBrickId: sourceId,
            destinationBrickIds: [destId],
            lagSeconds: 0,
            order: 0,
            column: 0,
            ganttChartId: chartId,
            notation: ""
        )
        modelContext.insert(new)
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
            // M5.7: traces are now created via tap-to-wire, not by
            // dragging the palette tile onto the canvas. The Trace
            // tile uses .onTapGesture (no .draggable) so this case
            // shouldn't be hit — but guard defensively.
            return false

        case .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            return false  // not palette tiles

        case .note, .marker, .trigger, .action,
             .group, .variable, .webhook,
             .conditional, .loop, .endBrick:
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
