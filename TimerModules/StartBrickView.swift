// MARK: - StartBrickView
//
// Visual rendering for one Start brick on the Gantt canvas.
//
// Locked design from Master Design Spec 2026-05-21 Part I § 2 + Part II § 12:
//   • 1×1 icon footprint (~60×60pt).
//   • play.circle.fill in green — symmetric with End's red stop.circle.fill.
//   • User-tappable: tap fires the Start (one-shot per run; re-arms on
//     program termination). Subsequent taps while data.hasFired are no-ops.
//   • Full module chrome: note.text glyph button top-right.
//   • Long-press / right-click → "Edit note…" context menu.
//
// SignalRouter wiring (Start's outgoing trace firing the cascade) lands
// in Phase 1.2 — this view fires a callback that the parent (GanttCanvasView)
// will route to SignalRouter. For now the callback toggles data.hasFired
// as a placeholder so the visual state changes are observable.

import SwiftUI
import SwiftData

struct StartBrickView: View {
    @Bindable var data: StartBrickData
    @Environment(\.modelContext) private var modelContext

    /// Invoked when the user taps the note.text glyph in the top-right
    /// corner. Parent owns the editor sheet so the same handler fires
    /// from both the glyph button and the long-press / right-click
    /// context menu.
    var onEditNoteTapped: () -> Void = {}

    /// Invoked when the user taps the Start button itself. Parent will
    /// route to SignalRouter in Phase 1.2; for now the StartBrickView
    /// updates hasFired so the visual state reflects the tap.
    var onStartTapped: () -> Void = {}

    /// Side length of the 1×1 icon footprint per the locked icon-grid.
    /// Matches iPhone home-screen icon size (~60pt).
    private let cellSize: CGFloat = 60

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // The Start button itself — full-cell tap target with the
            // play.circle.fill glyph in green.
            Button {
                guard !data.hasFired else { return }   // one-shot per run
                data.hasFired = true
                data.updatedDate = Date()
                onStartTapped()
            } label: {
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(data.hasFired ? Color.green.opacity(0.35) : Color.green)
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
