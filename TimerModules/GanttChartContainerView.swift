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

    /// Shared tap-to-wire state — when the user taps the Trace tile in
    /// the palette, this drives the canvas's source/destination tap
    /// flow. M5.7 (Michael 2026-05-19).
    @State private var wiring = WiringState()

    /// Per-chart heartbeat runtime. Owns the program's lifecycle
    /// state and the 1 Hz heartbeat timer. Initialized lazily via
    /// .task on first appearance so chartId is available.
    @State private var runner: ProgramRunner?

    @Environment(\.modelContext) private var modelContext

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
                            showingLog = true
                        },
                        onReset: {
                            runner.reset()
                        }
                    )
                }
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
