// MARK: - LogEntry
//
// SwiftData @Model recording one event in a Gantt chart's
// program execution. The Gantt chart is a program; the log is
// the receipt printer that records every event the program
// produces — Trigger fires, Timer starts/completes, Gate
// evaluates, Trace propagates, Action executes, Variable
// updates, Conditional branches, Loop iterates, and so on.

import Foundation
import SwiftData

@Model
final class LogEntry {
    /// Stable identifier.
    var id: UUID = UUID()

    /// Which Gantt chart's run this entry belongs to.
    var ganttChartId: UUID = UUID()

    /// Which brick produced this event (nil for chart-level events
    /// like "program start" or "program end").
    var brickId: UUID?

    /// Snapshot of the brick's BrickType.rawValue at log time, so
    /// the log entry stays meaningful even if the user later
    /// deletes the brick.
    var brickTypeRaw: String = ""

    /// Snapshot of the brick's notation/label at log time.
    var brickNotation: String = ""

    /// What happened. Examples:
    ///   "programStarted"     — Trigger fired, program kicked off
    ///   "programEnded"       — all bricks finished
    ///   "timerStarted"       — Timer brick began running
    ///   "timerCompleted"     — Timer brick reached its end
    ///   "timerReset"         — Timer brick was reset
    ///   "gateEvaluated"      — Gate brick computed its output
    ///   "gateFired"          — Gate brick's output went true
    ///   "tracePropagated"    — Trace forwarded a signal
    ///   "actionExecuted"     — Action brick ran its side effect
    ///   "webhookSent"        — Webhook brick made an HTTP request
    ///   "variableUpdated"    — Variable brick changed value
    ///   "conditionalBranched" — Conditional picked a branch
    ///   "loopIteration"      — Loop brick advanced one iteration
    var eventType: String = ""

    /// Free-form event-specific payload. JSON-encoded so any shape
    /// of data can be captured (e.g., webhook response body, gate
    /// input/output truth values, variable old/new pair).
    var payloadJSON: String = ""

    /// For timer-completion events: the elapsed time in seconds.
    /// Nil for non-timer events.
    var elapsedSeconds: TimeInterval?

    /// When this event occurred (real-world time, not program-time).
    var timestamp: Date = Date()

    /// Used to group log entries by program run. All entries from a
    /// single Trigger-fired program execution share the same runId.
    var runId: UUID = UUID()

    init(
        id: UUID = UUID(),
        ganttChartId: UUID,
        brickId: UUID? = nil,
        brickTypeRaw: String = "",
        brickNotation: String = "",
        eventType: String = "",
        payloadJSON: String = "",
        elapsedSeconds: TimeInterval? = nil,
        timestamp: Date = Date(),
        runId: UUID = UUID()
    ) {
        self.id = id
        self.ganttChartId = ganttChartId
        self.brickId = brickId
        self.brickTypeRaw = brickTypeRaw
        self.brickNotation = brickNotation
        self.eventType = eventType
        self.payloadJSON = payloadJSON
        self.elapsedSeconds = elapsedSeconds
        self.timestamp = timestamp
        self.runId = runId
    }
}
