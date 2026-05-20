// MARK: - GateBrickView
//
// Renders one logic-gate brick on the Gantt canvas. Visual
// language matches the palette tile: a large boolean operator
// text glyph (∧, ∨, ¬, ↓, ⊼, ⊕, ⊙) + the gate's display name +
// an editable user notation field.
//
// Inputs/outputs (ports for traces) come in M4 — for now the
// brick is a self-contained canvas element.

import SwiftUI
import SwiftData

struct GateBrickView: View {
    @Bindable var data: GateBrickData

    /// Invoked when the user taps the note.text glyph in the top-right
    /// corner (Michael 2026-05-20). The parent (GanttCanvasView) owns
    /// the editor sheet so the same handler fires from both the glyph
    /// button and the long-press / right-click context menu.
    var onEditNoteTapped: () -> Void = {}

    private var gateType: BrickType { data.gateType }

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            glyphFace
            gateNameLabel
        }
        .padding(8)
        .frame(width: 76)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            noteGlyphButton.padding(2)
        }
    }

    // MARK: Note glyph button — smaller for the compact gate card

    private var noteGlyphButton: some View {
        Button {
            onEditNoteTapped()
        } label: {
            Image(systemName: "note.text")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    data.note.isEmpty
                        ? AnyShapeStyle(Color.secondary.opacity(0.35))
                        : AnyShapeStyle(Color.cyan)
                )
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(data.note.isEmpty ? "Add note" : "Edit note")
    }

    // MARK: Distinctive-shape gate glyph (IEEE 91)
    //
    // Replaces the Unicode operator character with a SwiftUI Shape
    // that draws the actual schematic gate hieroglyph — D-shape
    // AND, curved OR, triangle NOT, etc. (Michael 2026-05-20).

    private var glyphFace: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.08))
            Circle()
                .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)

            GateGlyphShape(gateType: gateType)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                .aspectRatio(5.0/3.0, contentMode: .fit)
                .padding(8)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: Gate name (family subtitle dropped in compact layout)

    private var gateNameLabel: some View {
        Text(gateType.displayName)
            .font(.system(size: 13, weight: .bold))
            .lineLimit(1)
    }
}

#Preview {
    GateBrickView(
        data: GateBrickData(gateType: .andGate, notation: "Both prep done")
    )
    .modelContainer(for: GateBrickData.self, inMemory: true)
    .padding()
}
