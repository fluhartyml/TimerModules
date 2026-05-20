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

    // MARK: Operator glyph (shrunk to fit the compact card footprint)

    private var glyphFace: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.08))
            Circle()
                .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)

            Text(gateType.textGlyph ?? "?")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(Color.orange)
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
