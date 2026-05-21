// MARK: - TextLCDBrickView
//
// Visual rendering for one Text LCD brick on the Gantt canvas.
//
// Locked design from Master Design Spec Part II §19:
//   • 4×1 horizontal footprint (~245×60pt assuming 60pt cell +
//     gaps; we render it as a single solid strip with no internal
//     cell gaps so the text reads continuously).
//   • Displays:
//       - When no port has fired: the module's name (19.4).
//       - When a port has fired: that port's canned message
//         (or fallback to module name if the canned message is
//         empty). Persists until another port fires (19.5).
//   • Note glyph in top-right (subtle / cyan when populated).
//   • Long-press / right-click → edit-config (canned messages,
//     name) via context menu and modal sheet.

import SwiftUI
import SwiftData

struct TextLCDBrickView: View {
    @Bindable var data: TextLCDBrickData
    @Environment(\.modelContext) private var modelContext

    /// Invoked when the user taps the note.text glyph in the top-right
    /// corner. Parent owns the editor sheet.
    var onEditNoteTapped: () -> Void = {}

    /// 4 cells wide × 1 cell tall per the locked sizing.
    private let cellSize: CGFloat = 60
    private var width:  CGFloat { cellSize * 4 }
    private var height: CGFloat { cellSize }

    /// LCD-amber color for the text (e-ink-style readable on dark).
    private var amberOn: Color {
        Color(red: 1.0, green: 0.82, blue: 0.35)
    }

    /// Idle color — the same amber but slightly dimmed, signalling
    /// "module is named, no port has fired yet."
    private var amberIdle: Color {
        Color(red: 0.85, green: 0.70, blue: 0.32)
    }

    /// True when a port has fired and we're showing a canned message
    /// (vs. just showing the module's name in idle state).
    private var hasFiredAnyPort: Bool {
        data.currentPortIndex != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // LCD body — single horizontal strip with the message
            // rendered in a digital-style monospaced font.
            HStack(spacing: 0) {
                Text(data.displayedText)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(hasFiredAnyPort ? amberOn : amberIdle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.75))
            )

            // Note glyph in top-right corner of the LCD.
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
        .frame(width: width, height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Text LCD displaying: \(data.displayedText)")
    }
}
