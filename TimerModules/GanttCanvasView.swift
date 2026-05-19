// MARK: - GanttCanvasView
//
// The Gantt canvas — vertical list of rows where bricks live.
// Drop a brick from BrickPaletteView onto the canvas or its
// add-row drop zone to create a new instance. Timer modules and
// logic gates interleave on the canvas by their `order` field.
//
// M2 wires .timerModule end-to-end.
// M3 wires the seven boolean logic gates end-to-end (.andGate,
// .orGate, .notGate, .norGate, .nandGate, .xorGate, .xnorGate).
// M4 wires PM-dependency traces; M5 wires supplemental bricks.

import SwiftUI
import SwiftData

struct GanttCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerModuleData.order) private var timers: [TimerModuleData]
    @Query(sort: \GateBrickData.order) private var gates: [GateBrickData]

    @State private var isDropTargeted: Bool = false

    /// Polymorphic wrapper so timers and gates can interleave in a
    /// single ordered render loop.
    private enum CanvasBrick: Identifiable {
        case timer(TimerModuleData)
        case gate(GateBrickData)

        var id: UUID {
            switch self {
            case .timer(let t): return t.id
            case .gate(let g):  return g.id
            }
        }

        var order: Int {
            switch self {
            case .timer(let t): return t.order
            case .gate(let g):  return g.order
            }
        }
    }

    /// Combined timer + gate bricks, sorted by `order` for rendering.
    private var canvasBricks: [CanvasBrick] {
        let t = timers.map { CanvasBrick.timer($0) }
        let g = gates.map  { CanvasBrick.gate($0) }
        return (t + g).sorted { $0.order < $1.order }
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
            Text("Try the Timer tile or any logic gate from the palette above.")
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

    // MARK: Canvas row (polymorphic)

    @ViewBuilder
    private func canvasRow(for brick: CanvasBrick) -> some View {
        HStack(alignment: .top, spacing: 12) {
            rowHandle(for: brick)
            switch brick {
            case .timer(let timer):
                TimerModuleBrickView(data: timer)
            case .gate(let gate):
                GateBrickView(data: gate)
            }
            Spacer(minLength: 0)
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
        case .timer(let t): modelContext.delete(t)
        case .gate(let g):  modelContext.delete(g)
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

    // MARK: Drop handling

    private func handleDrop(_ items: [BrickType]) -> Bool {
        guard let type = items.first else { return false }
        guard type.isWiredUp else {
            // Type isn't wired yet (M4+ work); silently no-op.
            return false
        }

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

        default:
            // PM dependencies (M4) and supplemental bricks (M5)
            // route here when their isWiredUp flips.
            return false
        }
    }

    /// Next free `order` across both timer and gate bricks.
    private func nextAvailableOrder() -> Int {
        let highestTimer = timers.map(\.order).max() ?? -1
        let highestGate  = gates.map(\.order).max() ?? -1
        return max(highestTimer, highestGate) + 1
    }
}
