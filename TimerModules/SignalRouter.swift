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

enum SignalRouter {
    /// In-memory map of chart id → ProgramRunner. Each chart that
    /// is currently open registers its runner here so router calls
    /// can look up the heartbeat / run-state for the source chart.
    /// M5.7 (Michael 2026-05-19).
    private static var runners: [UUID: ProgramRunner] = [:]

    static func register(_ runner: ProgramRunner) {
        runners[runner.chartId] = runner
    }

    static func unregister(chartId: UUID) {
        runners[chartId] = nil
    }

    private static func currentRunId(for chartId: UUID) -> UUID {
        runners[chartId]?.currentRunId ?? UUID()
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

        log(
            eventType: "triggerFired",
            brickId: trigger.id,
            brickTypeRaw: trigger.brickTypeRaw,
            brickNotation: triggerLabel(trigger),
            ganttChartId: chartId,
            runId: runId,
            in: context
        )

        propagate(from: trigger.id, in: chartId, runId: runId, in: context)
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
            in: context
        )

        propagate(from: timer.id, in: chartId, runId: runId, in: context)
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
                deliver(signal: destId, via: trace, in: chartId, runId: runId, in: context)
            }
        }
    }

    private static func deliver(
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
            log(
                eventType: "gateInputReceived",
                brickId: gate.id,
                brickTypeRaw: gate.gateTypeRaw,
                brickNotation: gate.notation,
                ganttChartId: chartId,
                runId: runId,
                in: context
            )
            // Full gate evaluation lands in subsequent polish.
            return
        }
        if let sup = fetchOne(SupplementalBrickData.self, id: destId, chartId: chartId, in: context) {
            handleSupplementalSignal(sup, runId: runId, in: context)
            return
        }
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
        case .action:
            log(
                eventType: "actionExecuted",
                brickId: sup.id,
                brickTypeRaw: sup.brickTypeRaw,
                brickNotation: sup.notation,
                ganttChartId: chartId,
                payloadJSON: "{\"kind\":\"\(sup.kindRaw)\",\"config\":\"\(escape(sup.configString))\"}",
                runId: runId,
                in: context
            )
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
                in: context
            )
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
    }
}
