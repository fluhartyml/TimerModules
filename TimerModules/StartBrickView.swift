// MARK: - StartBrickView (Trigger module)
//
// Visual rendering for one Trigger module on the Gantt canvas.
// (File/type still named "Start" to preserve the SwiftData @Model
// identity; user-facing copy says "Trigger" per Michael's R&D
// session 2026-05-21.)
//
// Locked design from 2026-05-21 R&D:
//   • 1×1 icon footprint (~60×60pt).
//   • Single-pole momentary contact switch — stateless, no
//     hasFired lockout, no one-shot, no dim-on-fire. Tap the
//     button, signal pulse fires its output trace, button stays
//     ready for the next tap.
//   • No on-module label text (no notation rendered) — when a
//     human-readable label is wanted, the user places an
//     adjacent TextLCD module to carry it. The bare module
//     stays electrically pure.
//   • PUSH disc glyph: yellow-leaning filled circle with the
//     word "PUSH" punched out as negative space — mirrors the
//     way play.circle.fill (green) and stop.circle.fill (red)
//     render as single-color shapes with their operative
//     glyphs cut out.
//   • Corner note.text glyph (private author note) — same
//     chrome family as End and the other modules.
//   • No lifecycle coupling to "the program" — the act of
//     having a trace in flight IS the running state.

import SwiftUI
import SwiftData

struct StartBrickView: View {
    @Bindable var data: StartBrickData
    @Environment(\.modelContext) private var modelContext

    /// Invoked when the user taps the note.text glyph in the top-right
    /// corner. Parent owns the editor sheet.
    var onEditNoteTapped: () -> Void = {}

    /// Invoked when the user taps the Trigger pushbutton. Parent routes
    /// the firing through SignalRouter.
    var onStartTapped: () -> Void = {}

    /// Side length of the 1×1 icon footprint per the locked icon-grid.
    /// Matches iPhone home-screen icon size (~60pt).
    private let cellSize: CGFloat = 60

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // The Trigger pushbutton — stateless, fires on every tap.
            Button {
                onStartTapped()
            } label: {
                PushDisc()
                    .padding(2)
            }
            .buttonStyle(.plain)
            .frame(width: cellSize, height: cellSize)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.001)) // invisible hit-target backing
            )

            // Note glyph in top-right corner. Subtle when no note,
            // neon cyan when a note has been written.
            Button {
                onEditNoteTapped()
            } label: {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundStyle(data.note.isEmpty ? Color.secondary.opacity(0.4) : Color.cyan)
                    .padding(3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(data.note.isEmpty ? "Add note" : "Edit note")
        }
        .frame(width: cellSize, height: cellSize)
    }
}

// MARK: - PushDisc
//
// Yellow filled circle with "PUSH" punched out as negative space.
// Renders the operative glyph the same single-color way that
// play.circle.fill and stop.circle.fill render — solid disc,
// cutout text.

private struct PushDisc: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.yellow)
            Text("PUSH")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .kerning(0.5)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}
