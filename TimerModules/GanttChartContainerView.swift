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

    /// When the user clicks - on the column stepper and there are
    /// cards in the column to be removed, we present a confirmation
    /// before destroying them (Michael 2026-05-19).
    @State private var showingColumnRemoveConfirm = false
    @State private var columnRemoveTarget: (column: Int, cardCount: Int) = (0, 0)

    /// Shared tap-to-wire state — when the user taps the Trace tile in
    /// the palette, this drives the canvas's source/destination tap
    /// flow. M5.7 (Michael 2026-05-19).
    @State private var wiring = WiringState()

    /// Per-chart heartbeat runtime. Owns the program's lifecycle
    /// state and the 1 Hz heartbeat timer. Initialized lazily via
    /// .task on first appearance so chartId is available.
    @State private var runner: ProgramRunner?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                BrickPaletteView(wiring: wiring)
                    .frame(maxHeight: 200)

                Divider()

                GanttCanvasView(
                    chartId: chart.id,
                    columnCount: chart.columnCount,
                    wiring: wiring
                )
            }

            if wiring.isWiring {
                wiringBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: wiring.isWiring)
        .navigationTitle(chart.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
                if let runner = runner {
                    ProgramToggleButton(
                        runner: runner,
                        onStart: {
                            SignalRouter.startProgram(chartId: chart.id, in: modelContext)
                        },
                        onStop: {
                            // Halt all running timers in the chart so they
                            // don't keep counting in the background after
                            // the program state is "stopped" (Michael
                            // caught this bug 2026-05-19).
                            SignalRouter.stopAllRunningTimers(chartId: chart.id, in: modelContext)
                            runner.stopByUser(in: modelContext)
                            presentLog()
                        },
                        onReset: {
                            runner.reset()
                        }
                    )
                }
                Button {
                    presentLog()
                } label: {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            LogView(chartId: chart.id, chartName: chart.name)
        }
        .alert("Rename Timer Module", isPresented: $showingRename) {
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
        .onAppear {
            chart.lastOpenedDate = Date()
            if runner == nil {
                let newRunner = ProgramRunner(chartId: chart.id)
                runner = newRunner
                SignalRouter.register(newRunner)
            }
        }
        // When an End brick ends the program, auto-present the
        // summary popup. Platform-conditional — on Mac the log
        // opens as a real Window with traffic lights / drag-to-
        // move; on iOS it opens as a sheet.
        .onChange(of: runner?.state) { _, newState in
            if case .endedViaEndBrick = newState {
                presentLog()
            }
        }
        .onDisappear {
            SignalRouter.unregister(chartId: chart.id)
        }
    }

    /// Floating banner shown while the user is mid-wiring. Tells them
    /// what to do next and offers a Cancel button to exit wiring mode.
    private var wiringBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 18))
                .foregroundStyle(.white)
            Text(wiring.bannerText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                wiring.cancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor)
        .clipShape(Capsule())
        .shadow(radius: 6, y: 3)
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: 520)
    }

    private var columnStepper: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.split.3x1")
                .font(.caption)
            Button {
                attemptDecreaseColumns()
            } label: {
                Image(systemName: "minus.circle")
            }
            .disabled(chart.columnCount <= 1)
            Text("\(chart.columnCount) col\(chart.columnCount == 1 ? "" : "s")")
                .monospacedDigit()
                .font(.caption)
                .frame(minWidth: 36)
            Button {
                increaseColumns()
            } label: {
                Image(systemName: "plus.circle")
            }
            .disabled(chart.columnCount >= 10)
        }
        .alert(
            "Remove column \(columnRemoveTarget.column + 1)?",
            isPresented: $showingColumnRemoveConfirm
        ) {
            Button("Delete \(columnRemoveTarget.cardCount) card\(columnRemoveTarget.cardCount == 1 ? "" : "s")", role: .destructive) {
                deleteCardsInColumn(columnRemoveTarget.column)
                chart.columnCount = max(1, chart.columnCount - 1)
                chart.updatedDate = Date()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This column contains \(columnRemoveTarget.cardCount) card\(columnRemoveTarget.cardCount == 1 ? "" : "s"). Removing the column will delete \(columnRemoveTarget.cardCount == 1 ? "it" : "them"). This can't be undone.")
        }
    }

    /// Open the chart's execution log. On Mac we open a real
    /// Window (full chrome — traffic lights, drag-to-move,
    /// close button). On iOS we present a sheet with an
    /// always-visible Close button in its header.
    private func presentLog() {
        #if os(macOS)
        openWindow(
            id: "logWindow",
            value: LogWindowID(chartId: chart.id, chartName: chart.name)
        )
        #else
        showingLog = true
        #endif
    }

    private func increaseColumns() {
        chart.columnCount = min(10, chart.columnCount + 1)
        chart.updatedDate = Date()
    }

    /// Decrement column count. If there are cards in the column
    /// being removed (the highest one), prompt the user before
    /// destroying them. Otherwise decrement silently.
    private func attemptDecreaseColumns() {
        let columnToRemove = chart.columnCount - 1
        let count = countCardsInColumn(columnToRemove)
        if count > 0 {
            columnRemoveTarget = (column: columnToRemove, cardCount: count)
            showingColumnRemoveConfirm = true
        } else {
            chart.columnCount = max(1, chart.columnCount - 1)
            chart.updatedDate = Date()
        }
    }

    private func countCardsInColumn(_ column: Int) -> Int {
        let chartId = chart.id
        let t = (try? modelContext.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.column == column }
            )
        ))?.count ?? 0
        let g = (try? modelContext.fetch(
            FetchDescriptor<GateBrickData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.column == column }
            )
        ))?.count ?? 0
        let s = (try? modelContext.fetch(
            FetchDescriptor<SupplementalBrickData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.column == column }
            )
        ))?.count ?? 0
        return t + g + s
    }

    private func deleteCardsInColumn(_ column: Int) {
        let chartId = chart.id
        let timers = (try? modelContext.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.column == column }
            )
        )) ?? []
        for t in timers { modelContext.delete(t) }
        let gates = (try? modelContext.fetch(
            FetchDescriptor<GateBrickData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.column == column }
            )
        )) ?? []
        for g in gates { modelContext.delete(g) }
        let sups = (try? modelContext.fetch(
            FetchDescriptor<SupplementalBrickData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.column == column }
            )
        )) ?? []
        for s in sups { modelContext.delete(s) }
    }
}
