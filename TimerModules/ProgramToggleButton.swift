// MARK: - ProgramToggleButton
//
// Single toolbar button that morphs through the program's
// lifecycle states. Per Michael 2026-05-19 (M5.7):
//   "maybe the start button morphs into a pulsating stop
//    button a start stop toggle?"
//
// Three visual states:
//   • idle    — green capsule with ▶ play icon + "Start"
//                Press → starts the program (heartbeat + fire row 0)
//   • running — accent-color capsule with heart icon + "Stop"
//                Pulses scale 1.0↔1.08 on each heartbeat tick
//                Press → stops the program, presents summary
//   • ended   — red capsule with heart.slash icon + "Stopped"
//                Press → resets the runner back to idle, ready to
//                run again
//
// This replaces the separate StopButtonView (which only handled
// the running and ended states). The Start press also needs to
// fire the program's entry point — row 0's bricks — so the
// callback returns the action to perform via SignalRouter.

import SwiftUI

struct ProgramToggleButton: View {
    @Bindable var runner: ProgramRunner

    /// Called when the user presses the button while idle.
    /// Implementation should: call runner.start(in:) and then
    /// fire the row-0 entry-point bricks via SignalRouter.
    let onStart: () -> Void

    /// Called when the user presses the button while running.
    /// Implementation should: call runner.stopByUser(in:) and
    /// then present the summary popup.
    let onStop: () -> Void

    /// Called when the user presses the button in the ended
    /// state — resets the runner back to idle so the program can
    /// be run again.
    let onReset: () -> Void

    /// Drives the pulse animation by toggling on each tick.
    @State private var pulseUp: Bool = false

    var body: some View {
        Group {
            switch runner.state {
            case .idle:
                idleButton
            case .running:
                runningButton
            case .endedViaStop, .endedViaEndBrick:
                endedButton
            }
        }
    }

    // MARK: Idle — green Start

    private var idleButton: some View {
        Button {
            onStart()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                Text("Start")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.green))
        }
        .buttonStyle(.plain)
        .help("Start the program")
    }

    // MARK: Running — pulsating Stop
    //
    // Heartbeat pulse driven directly off `runner.tick` (1 Hz).
    // The background alternates between two distinct teal shades
    // on each tick (Michael 2026-05-20: "alternate one minute tiel
    // and the next minute a different shade of tiel back and forth
    // per heartbeat") AND scales the capsule 1.0 ↔ 1.12 so there's
    // both color and size feedback. Earlier the scale alone was too
    // subtle to read as a pulse.

    private var heartbeatTealA: Color { Color(red: 0.22, green: 0.72, blue: 0.74) }
    private var heartbeatTealB: Color { Color(red: 0.08, green: 0.45, blue: 0.52) }
    private var pulseTeal: Color {
        runner.tick.isMultiple(of: 2) ? heartbeatTealA : heartbeatTealB
    }

    private var runningButton: some View {
        Button {
            onStop()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                Text("Stop")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(pulseTeal))
            .scaleEffect(runner.tick.isMultiple(of: 2) ? 1.0 : 1.12)
            .animation(.easeInOut(duration: 0.45), value: runner.tick)
        }
        .buttonStyle(.plain)
        .help("Stop the program (currently running)")
    }

    // MARK: Ended — red, tap to reset

    private var endedButton: some View {
        Button {
            onReset()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "heart.slash.fill")
                Text("Stopped")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.red))
        }
        .buttonStyle(.plain)
        .help("The program ended — tap to reset and run again")
    }
}
