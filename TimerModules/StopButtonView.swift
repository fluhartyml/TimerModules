// MARK: - StopButtonView
//
// Toolbar button that visualizes the program's heartbeat state.
// Per Michael 2026-05-19 (M5.7):
//   "the stop button pulsates every second and then if pressed
//    it turns red and stops pulsating because the app had a
//    heartattach and stopped running"
//
// Three visual states:
//   • idle      — button hidden (returns EmptyView)
//   • running   — heart icon pulses 1× per second, accent color
//                 + tap action is stopByUser
//   • ended     — heart icon static, red, no longer interactive
//                 (briefly visible before the chart resets state
//                 after the summary popup is dismissed)

import SwiftUI

struct StopButtonView: View {
    @Bindable var runner: ProgramRunner
    let onStop: () -> Void

    /// Drives the .scaleEffect pulse via a binary toggle that
    /// flips on every heartbeat tick.
    @State private var pulseUp: Bool = false

    var body: some View {
        Group {
            switch runner.state {
            case .idle:
                EmptyView()
            case .running:
                runningButton
            case .endedViaStop, .endedViaEndBrick:
                endedButton
            }
        }
    }

    // MARK: Running — pulsating button

    private var runningButton: some View {
        Button {
            onStop()
        } label: {
            Label("Stop", systemImage: "heart.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.accentColor)
                )
                .scaleEffect(pulseUp ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: pulseUp)
                .onChange(of: runner.tick) { _, _ in
                    // Flip on each heartbeat — the SwiftUI animation
                    // interpolates the scale change smoothly.
                    pulseUp.toggle()
                }
                .onAppear {
                    // Kick off the first pulse so the animation
                    // doesn't wait for the second heartbeat.
                    pulseUp.toggle()
                }
        }
        .buttonStyle(.plain)
        .help("Stop the program (current state: running)")
    }

    // MARK: Ended — red static button

    private var endedButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.slash.fill")
            Text("Stopped")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.red)
        )
        .help("The program ended.")
    }
}
