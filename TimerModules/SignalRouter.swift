// MARK: - SignalRouter
//
// The engine that turns a Gantt chart from a static picture
// into a runnable program. When a Trigger brick fires, the
// router walks outgoing traces and propagates signals to
// downstream bricks; each step is logged to the chart's
// execution log so the user can see exactly what happened.
//
// v1.0 minimum: handles Trigger → Timer → Timer chains via
// FS / SS edges. Gates and supplementals receive log entries
// when signals reach them; full gate evaluation + side-effect
// execution lands in subsequent polish.

import Foundation
import SwiftData
import UserNotifications
import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SignalRouter {
    /// In-memory map of chart id → ProgramRunner. Each chart that
    /// is currently open registers its runner here so router calls
    /// can look up the heartbeat / run-state for the source chart.
    /// M5.7 (Michael 2026-05-19).
    private static var runners: [UUID: ProgramRunner] = [:]

    /// In-flight Loop iterations keyed by chartId → loopId. A loop
    /// becomes "running" the first time a signal lands on it; a
    /// second signal sets `haltRequested`; the current iteration
    /// finishes before the loop exits to its downstream.
    /// (Michael 2026-05-20 — until-signal Loop semantics.)
    private struct LoopState {
        var iterationCount: Int = 0
        var haltRequested: Bool = false
        /// Brick IDs in the loop body that haven't fired yet this
        /// iteration. Decremented as each completes; when empty, the
        /// iteration is over.
        var pendingBrickIds: Set<UUID> = []
    }
    private static var runningLoops: [UUID: [UUID: LoopState]] = [:]

    /// Safety cap so an unwired Loop (no halt source) can't iterate
    /// forever and lock the app.
    private static let loopSafetyCap: Int = 10_000

    static func register(_ runner: ProgramRunner) {
        runners[runner.chartId] = runner
    }

    static func unregister(chartId: UUID) {
        runners[chartId] = nil
    }

    private static func currentRunId(for chartId: UUID) -> UUID {
        runners[chartId]?.currentRunId ?? UUID()
    }

    /// Per-chart per-gate tally of which incoming traces have fired
    /// during the active run. Used by gate evaluation: AND fires
    /// when all incoming traces have fired; OR fires as soon as
    /// any one does. Reset each time a new run starts.
    private static var firedInputs: [UUID: [UUID: Set<UUID>]] = [:]
    // shape: [chartId: [gateId: Set<traceId>]]

    private static func resetFiredInputs(chartId: UUID) {
        firedInputs[chartId] = [:]
    }

    private static func recordInput(traceId: UUID, atGate gateId: UUID, chartId: UUID) {
        firedInputs[chartId, default: [:]][gateId, default: []].insert(traceId)
    }

    private static func firedInputCount(forGate gateId: UUID, chartId: UUID) -> Int {
        firedInputs[chartId]?[gateId]?.count ?? 0
    }

    /// Called when a Trigger brick's Start button is pressed.
    /// Starts a new program run on the trigger's chart and
    /// propagates signal from the trigger to its downstream
    /// bricks.
    static func fireProgram(
        from trigger: SupplementalBrickData,
        in context: ModelContext
    ) {
        guard let chartId = trigger.ganttChartId else { return }

        // Kick the heartbeat — the runner logs its own
        // programStarted entry. We avoid duplicating that here;
        // the trigger-level event below records WHICH brick
        // initiated the run.
        let runId = runners[chartId]?.start(in: context) ?? UUID()
        resetFiredInputs(chartId: chartId)

        log(
            eventType: "triggerFired",
            brickId: trigger.id,
            brickTypeRaw: trigger.brickTypeRaw,
            brickNotation: triggerLabel(trigger),
            ganttChartId: chartId,
            runId: runId,
            noteIfAny: trigger.note,
            in: context
        )

        propagate(from: trigger.id, in: chartId, runId: runId, in: context)
    }

    /// Halts every running timer in the chart, accumulating their
    /// elapsed time. Called when the user presses Stop so the
    /// program ending also stops the individual timers — otherwise
    /// timers keep counting in the background despite the program
    /// state being "ended" (Michael caught this bug 2026-05-19).
    static func stopAllRunningTimers(chartId: UUID, in context: ModelContext) {
        let runId = currentRunId(for: chartId)
        let runningTimers = (try? context.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.runningSince != nil }
            )
        )) ?? []

        for timer in runningTimers {
            if let started = timer.runningSince {
                timer.accumulatedSeconds += Date().timeIntervalSince(started)
            }
            timer.runningSince = nil
            timer.updatedDate = Date()

            log(
                eventType: "timerHaltedByStop",
                brickId: timer.id,
                brickTypeRaw: BrickType.timerModule.rawValue,
                brickNotation: timer.notation,
                ganttChartId: chartId,
                elapsedSeconds: timer.accumulatedSeconds,
                runId: runId,
                in: context
            )
        }
    }

    /// Called when the toolbar Start button is pressed. Starts the
    /// chart's heartbeat runner, then fires every brick on row 0
    /// as the program's entry-point set (Michael 2026-05-19 — row
    /// 0 is the natural entry point; Trigger bricks are explicit
    /// named entry points but not the only way to start a program).
    static func startProgram(chartId: UUID, in context: ModelContext) {
        guard let runner = runners[chartId] else { return }
        let runId = runner.start(in: context)
        resetFiredInputs(chartId: chartId)

        let row0Timers = (try? context.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.order == 0 }
            )
        )) ?? []
        let row0Sups = (try? context.fetch(
            FetchDescriptor<SupplementalBrickData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.order == 0 }
            )
        )) ?? []

        for timer in row0Timers {
            timer.runningSince = Date()
            timer.updatedDate = Date()
            log(
                eventType: "timerStarted",
                brickId: timer.id,
                brickTypeRaw: BrickType.timerModule.rawValue,
                brickNotation: timer.notation,
                ganttChartId: chartId,
                runId: runId,
                noteIfAny: timer.note,
                in: context
            )
            propagate(from: timer.id, in: chartId, runId: runId, in: context)
        }

        for sup in row0Sups {
            handleSupplementalSignal(sup, runId: runId, in: context)
            propagate(from: sup.id, in: chartId, runId: runId, in: context)
        }
    }

    /// Called when a Timer brick completes (countdown reached 0
    /// or user pressed Complete on count-up).
    static func fireTimerCompletion(
        _ timer: TimerModuleData,
        elapsed: TimeInterval,
        in context: ModelContext
    ) {
        guard let chartId = timer.ganttChartId else { return }
        let runId = currentRunId(for: chartId)

        log(
            eventType: "timerCompleted",
            brickId: timer.id,
            brickTypeRaw: BrickType.timerModule.rawValue,
            brickNotation: timer.notation,
            ganttChartId: chartId,
            elapsedSeconds: elapsed,
            runId: runId,
            noteIfAny: timer.note,
            in: context
        )

        // If this timer is in a running Loop's body, let the loop
        // tick its pending-set so it can iterate or exit.
        notifyLoopsOfTimerCompletion(
            timerId: timer.id,
            chartId: chartId,
            runId: runId,
            in: context
        )

        propagate(from: timer.id, in: chartId, runId: runId, in: context)

        // Row-barrier default flow: if this completion makes the
        // timer's row entirely done (no more running or unstarted
        // timers in the row), auto-fire every brick in the next
        // row (Michael 2026-05-19, M5.7).
        advanceRowIfRowComplete(
            chartId: chartId,
            completedRow: timer.order,
            runId: runId,
            in: context
        )
    }

    /// Checks whether every timer in the given row has completed.
    /// If so, fires every brick in the next row (timers get
    /// runningSince = now; supplementals run their side effects).
    /// This is the row-barrier default-flow advance described in
    /// the M5.7 design conversation.
    private static func advanceRowIfRowComplete(
        chartId: UUID,
        completedRow: Int,
        runId: UUID,
        in context: ModelContext
    ) {
        let timersInRow = (try? context.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.order == completedRow }
            )
        )) ?? []

        // Row is complete if every timer in it has been started
        // (accumulatedSeconds > 0) and is not currently running.
        let allDone = timersInRow.allSatisfy { t in
            t.runningSince == nil && t.accumulatedSeconds > 0
        }
        guard !timersInRow.isEmpty, allDone else { return }

        let nextRow = completedRow + 1
        let nextRowTimers = (try? context.fetch(
            FetchDescriptor<TimerModuleData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.order == nextRow }
            )
        )) ?? []
        let nextRowSups = (try? context.fetch(
            FetchDescriptor<SupplementalBrickData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.order == nextRow }
            )
        )) ?? []

        guard !nextRowTimers.isEmpty || !nextRowSups.isEmpty else {
            // No next row — program runs out the bottom. Heartbeat
            // keeps running until the user presses Stop or hits an
            // End brick (already handled).
            return
        }

        log(
            eventType: "rowAdvanced",
            brickId: nil,
            brickTypeRaw: "",
            brickNotation: "row \(completedRow) → row \(nextRow)",
            ganttChartId: chartId,
            runId: runId,
            in: context
        )

        for t in nextRowTimers {
            t.runningSince = Date()
            t.updatedDate = Date()
            log(
                eventType: "timerStarted",
                brickId: t.id,
                brickTypeRaw: BrickType.timerModule.rawValue,
                brickNotation: t.notation,
                ganttChartId: chartId,
                runId: runId,
                noteIfAny: t.note,
                in: context
            )
            propagate(from: t.id, in: chartId, runId: runId, in: context)
        }
        for s in nextRowSups {
            handleSupplementalSignal(s, runId: runId, in: context)
            propagate(from: s.id, in: chartId, runId: runId, in: context)
        }
    }

    // MARK: Propagation

    private static func propagate(
        from sourceId: UUID,
        in chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        let traces = (try? context.fetch(
            FetchDescriptor<TraceData>(
                predicate: #Predicate { $0.ganttChartId == chartId && $0.sourceBrickId == sourceId }
            )
        )) ?? []

        for trace in traces {
            log(
                eventType: "tracePropagated",
                brickId: trace.id,
                brickTypeRaw: BrickType.trace.rawValue,
                brickNotation: trace.notation,
                ganttChartId: chartId,
                payloadJSON: tracePayload(trace),
                runId: runId,
                in: context
            )

            for destId in trace.destinationBrickIds {
                deliver(traceId: trace.id, signal: destId, via: trace, in: chartId, runId: runId, in: context)
            }
        }
    }

    private static func deliver(
        traceId: UUID,
        signal destId: UUID,
        via trace: TraceData,
        in chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        // Look up the destination across all brick families. Return
        // on the first match so each id resolves once.
        if let timer = fetchOne(TimerModuleData.self, id: destId, chartId: chartId, in: context) {
            handleTimerSignal(timer, via: trace, runId: runId, in: context)
            return
        }
        if let gate = fetchOne(GateBrickData.self, id: destId, chartId: chartId, in: context) {
            recordInput(traceId: traceId, atGate: gate.id, chartId: chartId)
            log(
                eventType: "gateInputReceived",
                brickId: gate.id,
                brickTypeRaw: gate.gateTypeRaw,
                brickNotation: gate.notation,
                ganttChartId: chartId,
                runId: runId,
                in: context
            )
            evaluateAndPropagate(gate: gate, chartId: chartId, runId: runId, in: context)
            return
        }
        if let sup = fetchOne(SupplementalBrickData.self, id: destId, chartId: chartId, in: context) {
            handleSupplementalSignal(sup, runId: runId, in: context)
            return
        }
    }

    /// Evaluate a gate's boolean against its current fired-input
    /// state. If the gate evaluates true, log gateFired and
    /// propagate from the gate's id to outgoing traces.
    ///
    /// Reactive gates (AND, OR, NOT) settle immediately on input
    /// arrival. "Settle gates" (NOR, NAND, XNOR, XOR) need the
    /// heartbeat-driven settle moment to fire correctly without
    /// firing prematurely — they're handled but may fire on the
    /// first input arrival if their condition is already true
    /// (acceptable for v1; full settle timing is a polish pass).
    private static func evaluateAndPropagate(
        gate: GateBrickData,
        chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        // SwiftData's #Predicate macro doesn't support array.contains
        // with a captured value on the right side, so fetch all
        // chart traces and filter in Swift.
        let chartTraces = (try? context.fetch(
            FetchDescriptor<TraceData>(
                predicate: #Predicate { $0.ganttChartId == chartId }
            )
        )) ?? []
        let gateId = gate.id
        let allIncoming = chartTraces.filter { $0.destinationBrickIds.contains(gateId) }

        let firedSet = firedInputs[chartId]?[gate.id] ?? []
        let inputs: [Bool] = allIncoming.map { firedSet.contains($0.id) }

        let didFire = gate.evaluate(inputs: inputs)
        guard didFire else { return }

        // Guard against double-firing the same gate within one run.
        let firedGatesKey = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let gateFiredOnce = firedInputs[chartId]?[firedGatesKey]?.contains(gate.id) ?? false
        guard !gateFiredOnce else { return }
        firedInputs[chartId, default: [:]][firedGatesKey, default: []].insert(gate.id)

        log(
            eventType: "gateFired",
            brickId: gate.id,
            brickTypeRaw: gate.gateTypeRaw,
            brickNotation: gate.notation,
            ganttChartId: chartId,
            payloadJSON: "{\"inputs\":\(inputs),\"output\":true}",
            runId: runId,
            noteIfAny: gate.note,
            in: context
        )
        propagate(from: gate.id, in: chartId, runId: runId, in: context)
    }

    private static func handleTimerSignal(
        _ timer: TimerModuleData,
        via trace: TraceData,
        runId: UUID,
        in context: ModelContext
    ) {
        guard let chartId = timer.ganttChartId else { return }

        // FS / SS edges start the downstream timer. FF / SF would
        // affect completion; not modeled at run time in v1.0 minimum.
        switch trace.traceType {
        case .fsEdge, .ssEdge, .lagLead, .splitter:
            timer.runningSince = Date()
            timer.updatedDate = Date()
            log(
                eventType: "timerStarted",
                brickId: timer.id,
                brickTypeRaw: BrickType.timerModule.rawValue,
                brickNotation: timer.notation,
                ganttChartId: chartId,
                runId: runId,
                noteIfAny: timer.note,
                in: context
            )
        default:
            break
        }
    }

    private static func handleSupplementalSignal(
        _ sup: SupplementalBrickData,
        runId: UUID,
        in context: ModelContext
    ) {
        guard let chartId = sup.ganttChartId else { return }

        switch sup.brickType {
        case .endBrick:
            // Program flow reached an End brick — terminate the run.
            // Halt running timers, end the heartbeat, log it.
            stopAllRunningTimers(chartId: chartId, in: context)
            runners[chartId]?.stopByEndBrick(in: context)
            log(
                eventType: "endBrickReached",
                brickId: sup.id,
                brickTypeRaw: sup.brickTypeRaw,
                brickNotation: sup.notation,
                ganttChartId: chartId,
                runId: runId,
                noteIfAny: sup.note,
                in: context
            )

        case .action:
            log(
                eventType: "actionExecuted",
                brickId: sup.id,
                brickTypeRaw: sup.brickTypeRaw,
                brickNotation: sup.notation,
                ganttChartId: chartId,
                payloadJSON: "{\"kind\":\"\(sup.kindRaw)\",\"config\":\"\(escape(sup.configString))\"}",
                runId: runId,
                noteIfAny: sup.note,
                in: context
            )
            executeAction(sup)
        case .webhook:
            // Outbound HTTP. Fire-and-forget; the log captures
            // the attempt regardless of network success.
            log(
                eventType: "webhookSent",
                brickId: sup.id,
                brickTypeRaw: sup.brickTypeRaw,
                brickNotation: sup.notation,
                ganttChartId: chartId,
                payloadJSON: "{\"method\":\"\(sup.kindRaw)\",\"url\":\"\(escape(sup.configString))\"}",
                runId: runId,
                noteIfAny: sup.note,
                in: context
            )
            sendWebhook(sup)
        case .variable:
            sup.variableValue += 1
            sup.updatedDate = Date()
            log(
                eventType: "variableUpdated",
                brickId: sup.id,
                brickTypeRaw: sup.brickTypeRaw,
                brickNotation: sup.notation,
                ganttChartId: chartId,
                payloadJSON: "{\"value\":\(sup.variableValue)}",
                runId: runId,
                noteIfAny: sup.note,
                in: context
            )
        case .loop:
            handleLoopSignal(sup, runId: runId, in: context)
        default:
            log(
                eventType: "signalReceived",
                brickId: sup.id,
                brickTypeRaw: sup.brickTypeRaw,
                brickNotation: sup.notation,
                ganttChartId: chartId,
                runId: runId,
                in: context
            )
        }
    }

    // MARK: Loop semantics (Michael 2026-05-20)
    //
    // A Loop is "started" the first time it receives any signal.
    // A SECOND signal arrives during execution sets `haltRequested`
    // — the current iteration is allowed to finish, then the loop
    // exits to its downstream. Each iteration RESETS the contained
    // timers (accumulated = 0, runningSince = now) before firing
    // them, so they actually run their full duration each pass.

    private static func handleLoopSignal(
        _ loop: SupplementalBrickData,
        runId: UUID,
        in context: ModelContext
    ) {
        guard let chartId = loop.ganttChartId else { return }

        if runningLoops[chartId]?[loop.id] == nil {
            // First signal — start the loop
            startLoopIteration(loop, chartId: chartId, runId: runId, in: context)
        } else {
            // Subsequent signal — flag for halt at end of current iteration
            runningLoops[chartId]?[loop.id]?.haltRequested = true
            log(
                eventType: "loopHaltRequested",
                brickId: loop.id,
                brickTypeRaw: loop.brickTypeRaw,
                brickNotation: loop.notation,
                ganttChartId: chartId,
                runId: runId,
                in: context
            )
        }
    }

    private static func startLoopIteration(
        _ loop: SupplementalBrickData,
        chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        let prev = runningLoops[chartId]?[loop.id]
        let newCount = (prev?.iterationCount ?? 0) + 1

        if newCount > loopSafetyCap {
            log(
                eventType: "loopSafetyCapHit",
                brickId: loop.id,
                brickTypeRaw: loop.brickTypeRaw,
                brickNotation: loop.notation,
                ganttChartId: chartId,
                payloadJSON: "{\"cap\":\(loopSafetyCap)}",
                runId: runId,
                in: context
            )
            exitLoop(loop, chartId: chartId, runId: runId, in: context)
            return
        }

        // Only contained TIMERS are tracked for iteration completion.
        // Gates / actions / etc. fire once per iteration but don't
        // gate the iteration's progress.
        //
        // Sequencing within the body: ALL contained timers are reset
        // to zero accumulated each iteration, but only the "head"
        // timers — those with no incoming FS / SS edge from another
        // body brick — are started immediately. Their downstream
        // timers wait for the predecessor's completion to fire the
        // wire (Michael 2026-05-20: "the work block and the break
        // are both running, i probably should have trased them").
        let bodySet = Set(loop.containedBrickIds)
        let chartTraces: [TraceData] = (try? context.fetch(
            FetchDescriptor<TraceData>(
                predicate: #Predicate { $0.ganttChartId == chartId }
            )
        )) ?? []

        var pendingTimerIds: Set<UUID> = []
        for brickId in loop.containedBrickIds {
            if let timer = fetchOne(
                TimerModuleData.self, id: brickId, chartId: chartId, in: context
            ) {
                pendingTimerIds.insert(timer.id)
                timer.accumulatedSeconds = 0
                timer.updatedDate = Date()

                let hasIncomingFromBody = chartTraces.contains { trace in
                    guard trace.isWired, let src = trace.sourceBrickId else { return false }
                    return bodySet.contains(src)
                        && trace.destinationBrickIds.contains(timer.id)
                }

                if hasIncomingFromBody {
                    // Wait for predecessor's FS / SS edge to fire.
                    timer.runningSince = nil
                } else {
                    // Head of the dependency chain — start now.
                    timer.runningSince = Date()
                    log(
                        eventType: "timerStarted",
                        brickId: timer.id,
                        brickTypeRaw: BrickType.timerModule.rawValue,
                        brickNotation: timer.notation,
                        ganttChartId: chartId,
                        runId: runId,
                        noteIfAny: timer.note,
                        in: context
                    )
                }
            } else if let sup = fetchOne(
                SupplementalBrickData.self, id: brickId, chartId: chartId, in: context
            ) {
                handleSupplementalSignal(sup, runId: runId, in: context)
            }
        }

        runningLoops[chartId, default: [:]][loop.id] = LoopState(
            iterationCount: newCount,
            haltRequested: prev?.haltRequested ?? false,
            pendingBrickIds: pendingTimerIds
        )

        log(
            eventType: "loopIterationStarted",
            brickId: loop.id,
            brickTypeRaw: loop.brickTypeRaw,
            brickNotation: loop.notation,
            ganttChartId: chartId,
            payloadJSON: "{\"iteration\":\(newCount),\"bodySize\":\(pendingTimerIds.count)}",
            runId: runId,
            noteIfAny: loop.note,
            in: context
        )

        // If the body has NO timers at all the iteration is instantly
        // done — without this the loop would silently freeze.
        if pendingTimerIds.isEmpty {
            finishLoopIteration(loopId: loop.id, chartId: chartId, runId: runId, in: context)
        }
    }

    private static func finishLoopIteration(
        loopId: UUID,
        chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        guard let state = runningLoops[chartId]?[loopId],
              let loop = fetchOne(
                SupplementalBrickData.self, id: loopId, chartId: chartId, in: context
              ) else { return }

        if state.haltRequested {
            exitLoop(loop, chartId: chartId, runId: runId, in: context)
        } else {
            startLoopIteration(loop, chartId: chartId, runId: runId, in: context)
        }
    }

    private static func exitLoop(
        _ loop: SupplementalBrickData,
        chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        runningLoops[chartId]?[loop.id] = nil
        log(
            eventType: "loopExited",
            brickId: loop.id,
            brickTypeRaw: loop.brickTypeRaw,
            brickNotation: loop.notation,
            ganttChartId: chartId,
            runId: runId,
            in: context
        )
        propagate(from: loop.id, in: chartId, runId: runId, in: context)
    }

    /// Called by fireTimerCompletion right after a Timer logs its
    /// completion. If the timer is part of any running loop's pending
    /// set, decrement that set; when it empties, the iteration ends.
    private static func notifyLoopsOfTimerCompletion(
        timerId: UUID,
        chartId: UUID,
        runId: UUID,
        in context: ModelContext
    ) {
        guard let loops = runningLoops[chartId] else { return }
        for (loopId, _) in loops {
            guard var state = runningLoops[chartId]?[loopId] else { continue }
            if state.pendingBrickIds.contains(timerId) {
                state.pendingBrickIds.remove(timerId)
                runningLoops[chartId]?[loopId] = state
                if state.pendingBrickIds.isEmpty {
                    finishLoopIteration(
                        loopId: loopId,
                        chartId: chartId,
                        runId: runId,
                        in: context
                    )
                }
            }
        }
    }

    // MARK: Helpers

    private static func fetchOne<M: PersistentModel>(
        _ type: M.Type,
        id: UUID,
        chartId: UUID,
        in context: ModelContext
    ) -> M? {
        // Generic single-model fetch with id + chartId match. The
        // predicate is constructed per concrete type below — Swift's
        // KeyPath system doesn't let us write one predicate covering
        // all four brick @Models in a single function.
        switch type {
        case is TimerModuleData.Type:
            return (try? context.fetch(
                FetchDescriptor<TimerModuleData>(
                    predicate: #Predicate { $0.id == id && $0.ganttChartId == chartId }
                )
            ))?.first as? M
        case is GateBrickData.Type:
            return (try? context.fetch(
                FetchDescriptor<GateBrickData>(
                    predicate: #Predicate { $0.id == id && $0.ganttChartId == chartId }
                )
            ))?.first as? M
        case is SupplementalBrickData.Type:
            return (try? context.fetch(
                FetchDescriptor<SupplementalBrickData>(
                    predicate: #Predicate { $0.id == id && $0.ganttChartId == chartId }
                )
            ))?.first as? M
        default:
            return nil
        }
    }

    private static func triggerLabel(_ t: SupplementalBrickData) -> String {
        t.notation.isEmpty ? "Trigger" : t.notation
    }

    private static func tracePayload(_ t: TraceData) -> String {
        "{\"type\":\"\(t.traceTypeRaw)\",\"lagSeconds\":\(t.lagSeconds)}"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: Action firing
    //
    // Per Michael 2026-05-19 — when a Timer completes and a trace
    // routes to an Action card, we actually execute the side
    // effect the user configured. The user's message lives in
    // sup.configString; the kind is sup.kindRaw.

    private static func executeAction(_ sup: SupplementalBrickData) {
        switch sup.kindRaw {
        case "sound":
            playActionSound(named: sup.configString)

        case "notification":
            postLocalNotification(
                title: sup.notation.isEmpty ? "TimerModules" : sup.notation,
                body: sup.configString
            )

        case "log":
            // Already captured via the LogEntry written by the
            // caller; nothing further to do here.
            return

        case "link":
            openLink(sup.configString)

        default:
            return
        }
    }

    private static func playActionSound(named name: String) {
        let sound = ActionSound(rawValue: name) ?? .default
        AudioServicesPlaySystemSound(sound.soundID)
    }

    private static func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body.isEmpty ? "Timer reached this step." : body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { _ in
            // Authorization may not be granted; we silently drop.
            // App-launch flow requests authorization (see TimerModulesApp).
        }
    }

    private static func openLink(_ urlString: String) {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: Webhook firing

    private static func sendWebhook(_ sup: SupplementalBrickData) {
        guard let url = URL(string: sup.configString), !sup.configString.isEmpty else { return }
        var req = URLRequest(url: url)
        req.httpMethod = sup.kindRaw.isEmpty ? "POST" : sup.kindRaw
        if req.httpMethod != "GET", !sup.bodyContent.isEmpty {
            req.httpBody = sup.bodyContent.data(using: .utf8)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: Log helper

    private static func log(
        eventType: String,
        brickId: UUID?,
        brickTypeRaw: String,
        brickNotation: String,
        ganttChartId: UUID,
        payloadJSON: String = "",
        elapsedSeconds: TimeInterval? = nil,
        runId: UUID,
        noteIfAny: String? = nil,
        in context: ModelContext
    ) {
        let entry = LogEntry(
            ganttChartId: ganttChartId,
            brickId: brickId,
            brickTypeRaw: brickTypeRaw,
            brickNotation: brickNotation,
            eventType: eventType,
            payloadJSON: payloadJSON,
            elapsedSeconds: elapsedSeconds,
            timestamp: Date(),
            runId: runId
        )
        context.insert(entry)

        // Michael 2026-05-20: when a module fires or gains focus in
        // the program sequence, write a follow-up "moduleNote" entry
        // carrying the module's free-form note (if any). This keeps
        // the runtime log narrative-rich without firing on every
        // Save tap.
        if let note = noteIfAny, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let noteEntry = LogEntry(
                ganttChartId: ganttChartId,
                brickId: brickId,
                brickTypeRaw: brickTypeRaw,
                brickNotation: brickNotation,
                eventType: "moduleNote",
                payloadJSON: note,
                timestamp: Date(),
                runId: runId
            )
            context.insert(noteEntry)
        }
    }
}
