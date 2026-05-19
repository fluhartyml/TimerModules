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

    @State private var tick: Date = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var sweepAngle: Double = 0

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
        VStack(alignment: .center, spacing: 18) {
            notationField
            modeAndDurationControls
            analogDial
            startStopReset
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onReceive(ticker) { now in
            if isRunning { tick = now }
        }
    }

    // MARK: Notation field (the prominent user-label on the brick face)

    private var notationField: some View {
        TextField("Name this timer", text: $data.notation)
            .font(.system(size: 22, weight: .semibold))
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.tertiary),
                alignment: .bottom
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

            if data.mode == .countdown {
                HStack {
                    Text("Duration")
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
            }
        }
    }

    // MARK: Analog dial (lifted from HOS TimerSectionView lines 95-130)

    private var analogDial: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: 0.18)
                .stroke(
                    isRunning ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(sweepAngle - 90))
                .animation(
                    isRunning
                        ? .linear(duration: 2.5).repeatForever(autoreverses: false)
                        : .default,
                    value: sweepAngle
                )

            VStack(spacing: 4) {
                Text(formattedTime)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRunning ? Color.accentColor : .primary)
                    .contentTransition(.numericText())

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 220, height: 220)
        .onAppear {
            if isRunning { sweepAngle = 360 }
        }
        .onChange(of: isRunning) { _, nowRunning in
            sweepAngle = nowRunning ? 360 : 0
        }
    }

    // MARK: Start / Stop / Reset (lifted from HOS TimerSectionView lines 132-162)

    private var startStopReset: some View {
        HStack(spacing: 12) {
            if isRunning {
                Button {
                    stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
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
    }
}

#Preview {
    TimerModuleBrickView(
        data: TimerModuleData(notation: "Focus Cycle", mode: .countdown)
    )
    .modelContainer(for: TimerModuleData.self, inMemory: true)
    .padding()
}
