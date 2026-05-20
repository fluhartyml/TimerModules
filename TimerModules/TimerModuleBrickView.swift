// MARK: - TimerModuleBrickView
//
// One Timer module brick. Adapted from OPerationsHOS's
// TimerSectionView (per roadmap Section 2 lift). Differences from
// HOS:
//   • Binds to a standalone TimerModuleData @Model instead of
//     OperatorItem + OperatorStore.
//   • Includes the prominent user-notation TextField on the brick
//     face (roadmap Section 1.5.1).
//   • Mode toggle for countdown vs. count-up (roadmap Section 3.2).
//   • No project linkage menu (HOS-specific, dropped).
//
// One brick on screen for M1. M2 places multiple bricks on a
// Gantt canvas via drag-and-drop.

import SwiftUI
import SwiftData
import Combine

struct TimerModuleBrickView: View {
    @Bindable var data: TimerModuleData
    @Environment(\.modelContext) private var modelContext

    /// Invoked when the user taps the note.text glyph in the top-right
    /// corner (Michael 2026-05-20). The parent (GanttCanvasView) owns
    /// the editor sheet so the same handler fires from both the glyph
    /// button and the long-press / right-click context menu.
    var onEditNoteTapped: () -> Void = {}

    @State private var tick: Date = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var lastFiredAtElapsed: TimeInterval = -1

    /// Measured height of the three-line status text block. Drives the
    /// status circle's diameter so the circle stays sized to its
    /// neighbor (Michael 2026-05-20: "diameter of the timer 00:00
    /// complete and trigger at 1 min").
    @State private var statusTextHeight: CGFloat = 60

    // MARK: Computed state

    /// Total elapsed using the HOS pattern (lifted from
    /// TimerSectionView lines 12-18):
    /// accumulatedSeconds + (now − runningSince). Survives
    /// stop/start cleanly.
    private var elapsed: TimeInterval {
        var total = data.accumulatedSeconds
        if let started = data.runningSince {
            total += tick.timeIntervalSince(started)
        }
        return total
    }

    /// Remaining seconds for countdown mode (clamped at zero).
    private var remaining: TimeInterval {
        max(0, data.durationSeconds - elapsed)
    }

    /// What the dial displays — elapsed in count-up mode,
    /// remaining in countdown mode.
    private var displayedSeconds: TimeInterval {
        switch data.mode {
        case .countUp:    return elapsed
        case .countdown:  return remaining
        }
    }

    /// H:MM:SS over one hour, MM:SS under (lifted from HOS
    /// TimerSectionView lines 20-30).
    private var formattedTime: String {
        let total = Int(displayedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private var isRunning: Bool {
        data.runningSince != nil
    }

    private var isComplete: Bool {
        data.mode == .countdown && remaining <= 0 && data.accumulatedSeconds > 0
    }

    private var statusLabel: String {
        if isRunning { return "Running" }
        if isComplete { return "Complete" }
        if elapsed > 0 { return "Paused" }
        return "Idle"
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            notationField
            modeAndDurationControls
            compactStatus
            // Reserve a fixed height for the start/stop button row
            // so the brick's overall frame doesn't shift between
            // idle / running / paused states (Michael caught the
            // resulting visual "trace arrow jump" 2026-05-19).
            startStopReset
                .frame(height: 44)
        }
        .padding(16)
        .frame(width: 320, alignment: .top)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topTrailing) {
            noteGlyphButton.padding(6)
        }
        .onReceive(ticker) { now in
            if isRunning {
                tick = now
                // Countdown: auto-complete when remaining hits zero.
                if data.mode == .countdown,
                   remaining <= 0,
                   lastFiredAtElapsed < data.durationSeconds {
                    complete()
                }
            }
        }
    }

    // MARK: Note glyph button (top-right corner)
    //
    // Always visible. Subtle grey when no note exists; saturated
    // cyan when the module has notes. Tap → opens the note editor.
    // (Michael 2026-05-20.)

    private var noteGlyphButton: some View {
        Button {
            onEditNoteTapped()
        } label: {
            Image(systemName: "note.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    data.note.isEmpty
                        ? AnyShapeStyle(Color.secondary.opacity(0.35))
                        : AnyShapeStyle(Color.cyan)
                )
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(data.note.isEmpty ? "Add note" : "Edit note")
    }

    // MARK: Notation field (the prominent user-label on the brick face)

    private var notationField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            TextField("Name this timer", text: $data.notation)
                .font(.system(size: 22, weight: .semibold))
                .textFieldStyle(.plain)
                .submitLabel(.done)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Mode + duration

    private var modeAndDurationControls: some View {
        VStack(spacing: 10) {
            Picker("Mode", selection: $data.mode) {
                Text("Count up").tag(TimerMode.countUp)
                Text("Countdown").tag(TimerMode.countdown)
            }
            .pickerStyle(.segmented)
            .disabled(isRunning)

            // "Trigger at" stepper — sets the elapsed/remaining seconds
            // when a COUNTDOWN timer fires its completion signal. Hidden
            // for count-up because count-up is open-ended; the user
            // presses Complete manually when done (Michael 2026-05-19).
            if data.mode == .countdown {
                HStack(spacing: 12) {
                    Text("Trigger at")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        value: Binding(
                            get: { Int(data.durationSeconds / 60) },
                            set: { data.durationSeconds = TimeInterval($0) * 60 }
                        ),
                        in: 1...240
                    ) {
                        Text("\(Int(data.durationSeconds / 60)) min")
                            .monospacedDigit()
                    }
                }
                .font(.subheadline)
                .disabled(isRunning)
            } else {
                Text("Count-up — press Complete when done")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Compact status (replaces the HOS dial, Michael 2026-05-20)
    //
    // A small "status circle" to the LEFT of the time/status text
    // block. The circle's diameter is matched to the block's measured
    // height so the two read as visually paired. The text block keeps
    // its three lines (time, status word, trigger duration) but the
    // time numerals drop from 44pt to 18pt — the rest of the card no
    // longer has to defer to a 220pt dial.

    private var compactStatus: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .stroke(
                    isRunning ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: 3
                )
                .frame(width: statusTextHeight, height: statusTextHeight)

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRunning ? Color.accentColor : .primary)
                    .contentTransition(.numericText())

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if data.mode == .countdown {
                    Text("Trigger at \(Int(data.durationSeconds / 60)) min")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: StatusTextHeightKey.self,
                            value: proxy.size.height
                        )
                }
            )

            Spacer(minLength: 0)
        }
        .onPreferenceChange(StatusTextHeightKey.self) { newHeight in
            if newHeight > 0 { statusTextHeight = newHeight }
        }
    }

    // MARK: Start / Stop / Complete / Reset

    private var startStopReset: some View {
        HStack(spacing: 12) {
            if isRunning {
                if data.mode == .countdown {
                    // Countdown: Stop = pause. Auto-completes at zero.
                    Button {
                        stop()
                    } label: {
                        Label("Stop", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    // Count-up: Complete = stop + record elapsed +
                    // fire downstream signal (Michael 2026-05-19 —
                    // count-up is open-ended, completion is manual).
                    Button {
                        complete()
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            } else {
                Button {
                    start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isComplete)
            }

            if !isRunning && data.accumulatedSeconds > 0 {
                Button(role: .destructive) {
                    reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Actions

    private func start() {
        data.runningSince = Date()
        data.updatedDate = Date()
        tick = Date()
        lastFiredAtElapsed = -1
    }

    private func stop() {
        if let started = data.runningSince {
            data.accumulatedSeconds += Date().timeIntervalSince(started)
            data.runningSince = nil
            data.updatedDate = Date()
        }
    }

    private func reset() {
        data.accumulatedSeconds = 0
        data.runningSince = nil
        data.updatedDate = Date()
        lastFiredAtElapsed = -1
    }

    /// Manual completion for count-up timers (Michael 2026-05-19),
    /// AND automatic completion for countdown timers when the
    /// remaining time reaches zero. Captures the elapsed seconds at
    /// the moment of completion, stops the timer, fires the
    /// downstream signal via the signal router, and logs the event.
    private func complete() {
        let elapsedAtComplete = elapsed
        // Stop accumulating
        if let started = data.runningSince {
            data.accumulatedSeconds += Date().timeIntervalSince(started)
            data.runningSince = nil
            data.updatedDate = Date()
        }
        // Mark as fired to prevent re-firing on the same elapsed value
        lastFiredAtElapsed = elapsedAtComplete
        // Route downstream + log
        SignalRouter.fireTimerCompletion(
            data,
            elapsed: elapsedAtComplete,
            in: modelContext
        )
    }
}

/// PreferenceKey that propagates the measured height of the status
/// text block up to the parent HStack so the status circle can match
/// it (Michael 2026-05-20).
private struct StatusTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    TimerModuleBrickView(
        data: TimerModuleData(notation: "Focus Cycle", mode: .countdown)
    )
    .modelContainer(for: TimerModuleData.self, inMemory: true)
    .padding()
}
