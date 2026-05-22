// MARK: - LogView
//
// Per-chart execution log sheet (iOS) / window (Mac).
// Shows every LogEntry that belongs to the open Gantt chart,
// grouped by run (each Trigger / Start press shares a runId).
//
// Defaults to showing only the most recent run so iPhone users
// aren't drowned in historical events (Michael 2026-05-19).
// A toggle reveals all runs across the chart's history.

import SwiftUI
import SwiftData

struct LogView: View {
    let chartId: UUID
    let chartName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow
    @Query private var entries: [LogEntry]

    /// Default to current-run-only; user can flip to see history.
    @State private var showAllRuns: Bool = false

    init(chartId: UUID, chartName: String) {
        self.chartId = chartId
        self.chartName = chartName
        let id = chartId
        _entries = Query(
            filter: #Predicate<LogEntry> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            explicitHeader

            Group {
                if visibleRuns.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    // MARK: Header (always visible, works on both presentations)

    private var explicitHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chartName)
                    .font(.headline)
                    .lineLimit(1)
                Text(showAllRuns ? "All runs" : "Most recent run")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("All", isOn: $showAllRuns)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .help(showAllRuns ? "Showing all runs — toggle off for current only" : "Showing current run only — toggle on for full history")
            Button {
                closeView()
            } label: {
                Label("Close", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close the log")
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Log is empty")
                .font(.title3)
            Text("Press Start to run the program; events from each run land here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Entry list

    private var entryList: some View {
        List {
            ForEach(visibleRuns, id: \.0) { run in
                Section {
                    ForEach(run.1) { entry in
                        entryRow(entry)
                    }
                } header: {
                    runHeader(run.0, entries: run.1)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    /// Groups entries by runId, returning (runId, [entries]) tuples
    /// sorted with the most recent run first. Filtered by
    /// showAllRuns toggle.
    private var groupedByRun: [(UUID, [LogEntry])] {
        let grouped = Dictionary(grouping: entries, by: \.runId)
        return grouped
            .map { ($0.key, $0.value.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { ($0.1.first?.timestamp ?? Date.distantPast) > ($1.1.first?.timestamp ?? Date.distantPast) }
    }

    private var visibleRuns: [(UUID, [LogEntry])] {
        if showAllRuns {
            return groupedByRun
        }
        return Array(groupedByRun.prefix(1))
    }

    private func runHeader(_ runId: UUID, entries: [LogEntry]) -> some View {
        let start = entries.first?.timestamp ?? Date()
        let count = entries.count
        return HStack {
            Text("Run · \(start, format: .dateTime.month().day().hour().minute().second())")
                .font(.caption)
            Spacer()
            Text("\(count) event\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func entryRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(prettyEventType(entry.eventType))
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if !entry.brickNotation.isEmpty {
                Text(entry.brickNotation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let elapsed = entry.elapsedSeconds {
                Text("Elapsed: \(formatElapsed(elapsed))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if !entry.payloadJSON.isEmpty {
                Text(entry.payloadJSON)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
    }

    private func prettyEventType(_ raw: String) -> String {
        var result = ""
        for ch in raw {
            if ch.isUppercase, !result.isEmpty { result.append(" ") }
            result.append(ch)
        }
        return result.capitalized
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func closeView() {
        dismiss()
        dismissWindow(id: "logWindow")
    }
}
