// MARK: - LogView
//
// Per-chart execution log sheet. Shows every LogEntry that
// belongs to the open Gantt chart, newest first. Grouped by
// run (each Trigger-fired execution shares a runId).

import SwiftUI
import SwiftData

struct LogView: View {
    let chartId: UUID
    let chartName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow
    @Query private var entries: [LogEntry]

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
        NavigationStack {
            VStack(spacing: 0) {
                // Always-visible header with title + explicit Close
                // button. Belt-and-suspenders with the toolbar Done
                // — guarantees the user always has a dismiss
                // affordance regardless of platform (Michael
                // 2026-05-19 sheet-presentation bug).
                explicitHeader

                Group {
                    if entries.isEmpty {
                        emptyState
                    } else {
                        entryList
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    /// Header rendered inside the view body — works on iOS sheet
    /// and Mac window (where toolbar treatment differs / hides).
    private var explicitHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chartName)
                    .font(.headline)
                Text("Execution log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.bar)
    }

    /// Close handler — works for both presentation paths.
    /// .dismiss handles the sheet case (iOS); dismissWindow
    /// handles the WindowGroup case (Mac). Calling both is safe;
    /// each only acts in its applicable presentation context.
    private func closeView() {
        dismiss()
        dismissWindow(id: "logWindow")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Log is empty")
                .font(.title3)
            Text("Run the program (press a Trigger's Start button) to see events recorded here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entryList: some View {
        List {
            ForEach(groupedByRun, id: \.0) { run in
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
    /// sorted with the most recent run first.
    private var groupedByRun: [(UUID, [LogEntry])] {
        let grouped = Dictionary(grouping: entries, by: \.runId)
        return grouped
            .map { ($0.key, $0.value.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { ($0.1.first?.timestamp ?? Date.distantPast) > ($1.1.first?.timestamp ?? Date.distantPast) }
    }

    private func runHeader(_ runId: UUID, entries: [LogEntry]) -> some View {
        let start = entries.first?.timestamp ?? Date()
        let count = entries.count
        return HStack {
            Text("Run · \(start, format: .dateTime.month().day().hour().minute().second())")
            Spacer()
            Text("\(count) event\(count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
        }
    }

    private func entryRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(prettyEventType(entry.eventType))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            if !entry.brickNotation.isEmpty {
                Text(entry.brickNotation)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            if let elapsed = entry.elapsedSeconds {
                Text("Elapsed: \(formatElapsed(elapsed))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            if !entry.payloadJSON.isEmpty {
                Text(entry.payloadJSON)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func prettyEventType(_ raw: String) -> String {
        // camelCase → Title Case With Spaces
        var result = ""
        for ch in raw {
            if ch.isUppercase, !result.isEmpty {
                result.append(" ")
            }
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
}
