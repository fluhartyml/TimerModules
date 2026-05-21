// MARK: - DelayBrickView
//
// Visual rendering for one Delay brick on the Gantt canvas.
//
// Locked design from Master Design Spec Part II §18:
//   • 1×1 icon footprint (~60×60pt).
//   • Idle face shows the static configured display value
//     (e.g., "5" for a 6-second delay).
//   • When a signal arrives, the face shows a single-digit 7-segment
//     numeral counting down — like a "don't walk" crosswalk sign.
//   • When the countdown finishes its "0" hold (1 second), the Delay
//     fires its outgoing trace (the green-light moment).
//   • NOT tappable for run/pause — the only interaction is long-press
//     / right-click → edit config (per 4.11 lock for 1×1 modules).
//   • Note glyph in top-right corner.

import SwiftUI
import SwiftData

struct DelayBrickView: View {
    @Bindable var data: DelayBrickData
    @Environment(\.modelContext) private var modelContext

    /// Invoked when the user taps the note.text glyph in the top-right
    /// corner. Parent owns the editor sheet.
    var onEditNoteTapped: () -> Void = {}

    /// Side length of the 1×1 icon footprint.
    private let cellSize: CGFloat = 60

    /// The digit currently displayed — either the runtime countdown
    /// (when signal in flight) or the static configured value (idle).
    private var displayedDigit: Int {
        data.currentCountdown ?? data.displayValue
    }

    /// Idle vs. counting-down state drives the digit color intensity.
    private var isCountingDown: Bool {
        data.currentCountdown != nil
    }

    /// Lit color — bright amber when counting down (active LED), dim
    /// amber when idle (still readable but obviously inactive).
    private var litColor: Color {
        if isCountingDown {
            return Color(red: 1.0, green: 0.55, blue: 0.10)  // bright orange
        } else {
            return Color(red: 0.65, green: 0.50, blue: 0.20)  // dim amber
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // The 7-segment digit takes the cell's center.
            SevenSegmentDigit(
                digit: displayedDigit,
                litColor: litColor,
                dimColor: Color.black.opacity(0.18)  // faint ghost of unlit segments
            )
            .padding(4)
            .frame(width: cellSize, height: cellSize)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.65))
            )

            // Note glyph in top-right corner.
            Button {
                onEditNoteTapped()
            } label: {
                Image(systemName: "note.text")
                    .font(.system(size: 9))
                    .foregroundStyle(data.note.isEmpty ? Color.secondary.opacity(0.4) : Color.cyan)
                    .padding(2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(data.note.isEmpty ? "Add note" : "Edit note")
        }
        .frame(width: cellSize, height: cellSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isCountingDown
                ? "Delay counting down, \(displayedDigit) seconds remaining"
                : "Delay configured for \(data.heldSeconds) seconds"
        )
    }
}
