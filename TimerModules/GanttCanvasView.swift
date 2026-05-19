// MARK: - GanttCanvasView
//
// The Gantt canvas — vertical list of rows where bricks live.
// Drop a brick from BrickPaletteView onto the canvas (or its empty
// drop zone) to create a new instance. Existing TimerModuleData
// instances render as rows, each containing a TimerModuleBrickView.
//
// M2 wires Timer module bricks end-to-end. Other brick types
// (gates, PM edges, supplemental) accept drops at the canvas level
// but show a placeholder row until their wiring lands in M3-M5.

import SwiftUI
import SwiftData

struct GanttCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerModuleData.order) private var timers: [TimerModuleData]

    @State private var isDropTargeted: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if timers.isEmpty {
                    emptyCanvasHint
                        .dropDestination(for: BrickType.self) { items, _ in
                            handleDrop(items)
                        } isTargeted: { targeted in
                            isDropTargeted = targeted
                        }
                } else {
                    ForEach(timers) { timer in
                        timerRow(for: timer)
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
            Text("Try the Timer tile from the palette above.")
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

    // MARK: Timer row

    private func timerRow(for timer: TimerModuleData) -> some View {
        HStack(alignment: .top, spacing: 12) {
            rowHandle(for: timer)
            TimerModuleBrickView(data: timer)
            Spacer(minLength: 0)
        }
    }

    /// Row handle on the left with the row number and a delete affordance.
    private func rowHandle(for timer: TimerModuleData) -> some View {
        VStack(spacing: 6) {
            Text("\(timer.order + 1)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(.thinMaterial)
                )

            Button {
                modelContext.delete(timer)
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
            // Type isn't wired yet (M3+ work); silently no-op.
            // Visual feedback in the palette already shows it as dimmed.
            return false
        }

        switch type {
        case .timerModule:
            let nextOrder = (timers.map(\.order).max() ?? -1) + 1
            let new = TimerModuleData(
                notation: "Timer \(nextOrder + 1)",
                order: nextOrder
            )
            modelContext.insert(new)
            return true

        default:
            // Other wired-up types land here in later milestones.
            return false
        }
    }
}
