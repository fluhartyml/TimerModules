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
    @State private var chartToRename: GanttChartData?
    @State private var renameDraft: String = ""
    @State private var showingRename = false

    var body: some View {
        Group {
            if charts.isEmpty {
                emptyState
            } else {
                chartList
            }
        }
        .navigationTitle("My Timer Modules")
        #if os(macOS)
        .navigationSubtitle("Gantt charts (internal nomenclature)")
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewChart()
                } label: {
                    Label("New Timer Module", systemImage: "plus")
                }
            }
        }
        .onAppear {
            bootstrapIfNeeded()
        }
        .confirmationDialog(
            "Delete this Timer Module?",
            isPresented: $showingDeleteConfirm,
            presenting: chartToDelete
        ) { chart in
            Button("Delete \"\(chart.name)\"", role: .destructive) {
                deleteChart(chart)
            }
        } message: { _ in
            Text("All bricks and log entries in this Timer Module will be deleted. This can't be undone.")
        }
        .alert("Rename Timer Module", isPresented: $showingRename, presenting: chartToRename) { chart in
            TextField("Name", text: $renameDraft)
            Button("Save") {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    chart.name = trimmed
                    chart.updatedDate = Date()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No module canvas yet")
                .font(.title2)
            Text("Press + to make your first module canvas.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                .contextMenu {
                    Button {
                        chartToRename = chart
                        renameDraft = chart.name
                        showingRename = true
                    } label: {
                        Label("Rename Timer Module", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        chartToDelete = chart
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Timer Module", systemImage: "trash")
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

    /// No auto-seed. Per Michael 2026-05-22: "it shouldnt make a new
    /// canvas in the first place." First-launch users see the empty-
    /// state UI ("Create your first Timer Module to start building a
    /// program") and the explicit "New Timer Module" button, which
    /// calls createNewChart(). Orphan adoption still runs so any pre-
    /// existing bricks without a chart get attached to the first chart
    /// once one exists.
    private func bootstrapIfNeeded() {
        if let first = charts.first, hasOrphans {
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
        let nextName = "Timer Module \(charts.count + 1)"
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
