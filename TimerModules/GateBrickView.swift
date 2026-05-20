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
                .frame(width: 42, height: 25)
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
