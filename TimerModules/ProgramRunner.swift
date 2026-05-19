// MARK: - ProgramRunner
//
// Heartbeat runtime for a Gantt chart's program execution.
// One instance per chart (owned by GanttChartContainerView).
//
// Per Michael 2026-05-19 (M5.7):
//   "maybe this has to be a heartbeat the app generates to let
//    the nor gate know the 'program' is running untill the end
//    module is reached or the stop button has been pushed"
//
// The runner:
//   • Tracks the chart's program state (idle / running / ended).
//   • Owns a 1 Hz heartbeat timer that ticks while the program
//     is running. Tick count is exposed for the pulsating Stop
//     button and for gate-settle evaluation.
//   • Logs program-start and program-end events to the chart's
//     execution log.
//   • Halts on End brick reached OR user-pressed Stop OR program
//     reaches a quiescent state with no more events to fire
//     (future polish — for now requires explicit Stop / End).

import Foundation
import SwiftUI
import SwiftData

@Observable
final class ProgramRunner {
    enum State: Equatable {
        case idle
        case running(runId: UUID, startedAt: Date)
        case endedViaEndBrick(runId: UUID, endedAt: Date)
        case endedViaStop(runId: UUID, endedAt: Date)
    }

    let chartId: UUID

    private(set) var state: State = .idle

    /// Increments on every heartbeat tick while running. Used by
    /// the pulsating Stop button UI to animate in sync with the
    /// heartbeat, and (future) by gate-settle evaluation.
    private(set) var tick: Int = 0

    private var timer: Timer?

    init(chartId: UUID) {
        self.chartId = chartId
    }

    // MARK: Convenience accessors

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isEnded: Bool {
        switch state {
        case .endedViaEndBrick, .endedViaStop: return true
        default: return false
        }
    }

    var currentRunId: UUID? {
        switch state {
        case .running(let id, _),
             .endedViaEndBrick(let id, _),
             .endedViaStop(let id, _):
            return id
        case .idle:
            return nil
        }
    }

    // MARK: Lifecycle

    /// Begin a program run. Returns the new runId. Idempotent if
    /// already running (returns the existing runId).
    @discardableResult
    func start(in context: ModelContext) -> UUID {
        if case .running(let id, _) = state { return id }

        let runId = UUID()
        state = .running(runId: runId, startedAt: Date())
        tick = 0

        log(eventType: "programStarted", in: context, runId: runId)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.handleHeartbeat(in: context)
        }
        return runId
    }

    /// User pressed Stop — halt the heartbeat and mark the end.
    func stopByUser(in context: ModelContext) {
        guard case .running(let runId, _) = state else { return }
        timer?.invalidate()
        timer = nil
        state = .endedViaStop(runId: runId, endedAt: Date())
        log(eventType: "programStoppedByUser", in: context, runId: runId)
    }

    /// An End brick was reached — clean termination.
    func stopByEndBrick(in context: ModelContext) {
        guard case .running(let runId, _) = state else { return }
        timer?.invalidate()
        timer = nil
        state = .endedViaEndBrick(runId: runId, endedAt: Date())
        log(eventType: "programEnded", in: context, runId: runId)
    }

    /// Clear ended state and return to idle. Called when the user
    /// dismisses the post-run summary so the chart is ready to
    /// run again from a fresh state.
    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        tick = 0
    }

    // MARK: Heartbeat

    private func handleHeartbeat(in context: ModelContext) {
        guard isRunning else { return }
        tick += 1
        // Future work: drive gate settle evaluation on each tick
        // (M5.7 phase 4 — input gating + heartbeat-driven evaluation).
    }

    // MARK: Logging

    private func log(eventType: String, in context: ModelContext, runId: UUID) {
        let entry = LogEntry(
            ganttChartId: chartId,
            brickId: nil,
            brickTypeRaw: "",
            brickNotation: "",
            eventType: eventType,
            payloadJSON: "",
            elapsedSeconds: nil,
            timestamp: Date(),
            runId: runId
        )
        context.insert(entry)
    }
}
