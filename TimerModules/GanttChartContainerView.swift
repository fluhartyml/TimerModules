// MARK: - GanttChartContainerView
//
// One Gantt chart open in the app. Hosts the brick palette and
// the canvas. The canvas is scoped to this chart's id so its
// @Queries filter accordingly.
//
// Toolbar items:
//   • Chart name (editable)
//   • Column-count stepper (1...10 — user-defined width per
//     Michael 2026-05-19)
//   • View Log button (opens the per-chart execution log)
//   • Print button (M5.6 export — placeholder for now)

import SwiftUI
import SwiftData

struct GanttChartContainerView: View {
    @Bindable var chart: GanttChartData

    @State private var showingLog = false
    @State private var showingRename = false
    @State private var renameDraft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            BrickPaletteView()
                .frame(maxHeight: 200)

            Divider()

            GanttCanvasView(chartId: chart.id, columnCount: chart.columnCount)
        }
        .navigationTitle(chart.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    renameDraft = chart.name
                    showingRename = true
                } label: {
                    HStack(spacing: 4) {
                        Text(chart.name)
                            .font(.headline)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                columnStepper
                Button {
                    showingLog = true
                } label: {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            LogView(chartId: chart.id, chartName: chart.name)
        }
        .alert("Rename chart", isPresented: $showingRename) {
            TextField("Chart name", text: $renameDraft)
            Button("Save") {
                chart.name = renameDraft.trimmingCharacters(in: .whitespaces)
                chart.updatedDate = Date()
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            chart.lastOpenedDate = Date()
        }
    }

    private var columnStepper: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.split.3x1")
                .font(.caption)
            Stepper(
                value: $chart.columnCount,
                in: 1...10
            ) {
                Text("\(chart.columnCount)")
                    .monospacedDigit()
                    .font(.caption)
                    .frame(width: 18)
            }
            .labelsHidden()
        }
    }
}
