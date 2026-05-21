// MARK: - HeartbeatIndicatorView
//
// Pure visual chrome that replaces the tap-controlling
// ProgramToggleButton (removed in Phase 8.3).
//
// Locked design from Master Design Spec Part I §5 + 5.20:
//   • NOT tappable — pure visual chrome, read-only.
//   • Binary state: PULSE = running, SOLID = stopped.
//   • PULSE alternates between a color and its shade on each
//     1Hz heartbeat tick.
//   • Default running color: teal + teal-shade.
//   • Default stopped color: solid red, no alternation.
//   • Status module can override the running color to red / yellow /
//     green (with each color's shade), wired via the Status module's
//     three colored input ports. (Status module override is locked
//     for the design but the wiring lands in a later phase.)
//
// The program is started via the Start module on the canvas
// (per fireProgramFromStart) or via a Trigger; the toolbar Start
// button is gone. The program ends via End modules (or by reaching
// natural completion via stopAllRunningTimers / endBrickReached).

import SwiftUI

struct HeartbeatIndicatorView: View {
    @Bindable var runner: ProgramRunner

    // MARK: Color vocabulary (Master Design Spec 5.7 — closed set,
    // hard-coded, user-cannot-redefine).

    /// Lighter teal — the "A" half of the running default pulse.
    private var tealA: Color { Color(red: 0.22, green: 0.72, blue: 0.74) }

    /// Darker teal — the "B" half of the running default pulse.
    private var tealB: Color { Color(red: 0.08, green: 0.45, blue: 0.52) }

    /// Solid red — the stopped color (5.5: "just one solid red
    /// because the heartbeat is dead").
    private var stoppedRed: Color { Color(red: 0.78, green: 0.16, blue: 0.16) }

    /// Active color for the running default — alternates per 1Hz
    /// tick (5.4 + 5.3: PULSE = running).
    private var runningPulseColor: Color {
        runner.tick.isMultiple(of: 2) ? tealA : tealB
    }

    /// SF Symbol — heart while running (alive), heart.slash when
    /// stopped (dead).
    private var symbolName: String {
        switch runner.state {
        case .running:  return "heart.fill"
        case .idle, .endedViaStop, .endedViaEndBrick:
            return "heart.slash.fill"
        }
    }

    /// Background color per state.
    private var backgroundColor: Color {
        switch runner.state {
        case .running:  return runningPulseColor
        case .idle, .endedViaStop, .endedViaEndBrick:
            return stoppedRed
        }
    }

    /// Scale factor — PULSE animation while running (1.0↔1.12 per
    /// tick); SOLID (no scale change) when stopped (5.3: "When
    /// stopped, the indicator is SOLID — no alternation").
    private var scale: CGFloat {
        switch runner.state {
        case .running:  return runner.tick.isMultiple(of: 2) ? 1.0 : 1.12
        case .idle, .endedViaStop, .endedViaEndBrick:
            return 1.0
        }
    }

    /// Read-only accessibility label so the heartbeat is announced
    /// correctly to VoiceOver but the user cannot interact with it.
    private var accessibilityText: String {
        switch runner.state {
        case .running:                return "Program running, heartbeat alive"
        case .idle:                   return "Program stopped, heartbeat dead"
        case .endedViaStop:           return "Program stopped by user"
        case .endedViaEndBrick:       return "Program ended at End module"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
            // No text label — pure indicator. Per 5.20 it's chrome,
            // not a button, and shouldn't read like one.
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(backgroundColor))
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.45), value: runner.tick)
        .animation(.easeInOut(duration: 0.25), value: runner.state)
        // Locked design 5.20: indicator is NOT tappable. .allowsHitTesting(false)
        // ensures taps pass through to whatever's underneath (which is nothing
        // in the toolbar; this is belt-and-suspenders against accidental tap
        // capture from any SwiftUI parent that might add tap handlers later).
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }
}
