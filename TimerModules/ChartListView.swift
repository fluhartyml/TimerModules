// MARK: - ChartListView
//
// Top-level navigation root. Shows the list of saved Gantt
// charts (programs). User can:
//   • Create a new chart
//   • Open an existing chart → navigates into GanttChartContainerView
//   • Rename a chart
//   • Delete a chart (with confirmation)
//
// Auto-creates a "My First Gantt" on first launch if no charts
// exist, and assigns any pre-M5.5 orphan bricks (ganttChartId
// = nil) to it so the user doesn't lose existing work.

import SwiftUI
import SwiftData

struct ChartListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GanttChartData.lastOpenedDate, order: .reverse)
    private var charts: [GanttChartData]

    // Orphan-brick adoption: any brick with ganttChartId == nil
    // gets reassigned to the first chart at launch.
    @Query(filter: #Predicate<TimerModuleData> { $0.ganttChartId == nil })
    private var orphanTimers: [TimerModuleData]
    @Query(filter: #Predicate<GateBrickData> { $0.ganttChartId == nil })
    private var orphanGates: [GateBrickData]
    @Query(filter: #Predicate<TraceData> { $0.ganttChartId == nil })
    private var orphanTraces: [TraceData]
    @Query(filter: #Predicate<SupplementalBrickData> { $0.ganttChartId == nil })
    private var orphanSupplementals: [SupplementalBrickData]

    @State private var chartToDelete: GanttChartData?
    @State private var showingDeleteConfirm = false

    var body: some View {
        Group {
            if charts.isEmpty {
                emptyState
            } else {
                chartList
            }
        }
        .navigationTitle("My Gantt Charts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewChart()
                } label: {
                    Label("New Chart", systemImage: "plus")
                }
            }
        }
        .onAppear {
            bootstrapIfNeeded()
        }
        .confirmationDialog(
            "Delete this chart?",
            isPresented: $showingDeleteConfirm,
            presenting: chartToDelete
        ) { chart in
            Button("Delete \"\(chart.name)\"", role: .destructive) {
                deleteChart(chart)
            }
        } message: { _ in
            Text("All bricks and log entries in this chart will be deleted. This can't be undone.")
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No Gantt charts yet")
                .font(.title2)
            Text("Create your first chart to start building a program.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                createNewChart()
            } label: {
                Label("New Chart", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Chart list

    private var chartList: some View {
        List {
            ForEach(charts) { chart in
                NavigationLink(value: chart.id) {
                    chartRow(chart)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        chartToDelete = chart
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationDestination(for: UUID.self) { chartId in
            if let chart = charts.first(where: { $0.id == chartId }) {
                GanttChartContainerView(chart: chart)
            }
        }
    }

    private func chartRow(_ chart: GanttChartData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chart.name)
                .font(.headline)
            HStack(spacing: 12) {
                Label("\(chart.columnCount) col\(chart.columnCount == 1 ? "" : "s")",
                      systemImage: "rectangle.split.3x1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(chart.lastOpenedDate, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Bootstrap + actions

    private func bootstrapIfNeeded() {
        if charts.isEmpty {
            let firstChart = GanttChartData(
                name: "My First Gantt",
                notation: "",
                columnCount: 1
            )
            modelContext.insert(firstChart)
            adoptOrphans(into: firstChart.id)
        } else if let first = charts.first, hasOrphans {
            adoptOrphans(into: first.id)
        }
    }

    private var hasOrphans: Bool {
        !(orphanTimers.isEmpty
          && orphanGates.isEmpty
          && orphanTraces.isEmpty
          && orphanSupplementals.isEmpty)
    }

    private func adoptOrphans(into chartId: UUID) {
        for t in orphanTimers        { t.ganttChartId = chartId }
        for g in orphanGates         { g.ganttChartId = chartId }
        for r in orphanTraces        { r.ganttChartId = chartId }
        for s in orphanSupplementals { s.ganttChartId = chartId }
    }

    private func createNewChart() {
        let nextName = "New Gantt \(charts.count + 1)"
        let chart = GanttChartData(name: nextName, columnCount: 1)
        modelContext.insert(chart)
    }

    private func deleteChart(_ chart: GanttChartData) {
        // Cascade-delete the chart's bricks and log entries.
        let chartId = chart.id
        do {
            let timers = try modelContext.fetch(
                FetchDescriptor<TimerModuleData>(predicate: #Predicate { $0.ganttChartId == chartId })
            )
            for t in timers { modelContext.delete(t) }

            let gates = try modelContext.fetch(
                FetchDescriptor<GateBrickData>(predicate: #Predicate { $0.ganttChartId == chartId })
            )
            for g in gates { modelContext.delete(g) }

            let traces = try modelContext.fetch(
                FetchDescriptor<TraceData>(predicate: #Predicate { $0.ganttChartId == chartId })
            )
            for r in traces { modelContext.delete(r) }

            let sups = try modelContext.fetch(
                FetchDescriptor<SupplementalBrickData>(predicate: #Predicate { $0.ganttChartId == chartId })
            )
            for s in sups { modelContext.delete(s) }

            let logs = try modelContext.fetch(
                FetchDescriptor<LogEntry>(predicate: #Predicate { $0.ganttChartId == chartId })
            )
            for l in logs { modelContext.delete(l) }
        } catch {
            // Non-fatal — proceed to delete the chart itself.
        }

        modelContext.delete(chart)
    }
}
