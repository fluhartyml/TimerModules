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
        VStack(alignment: .center, spacing: 16) {
            notationField
            glyphFace
            gateNameLabel
        }
        .padding(20)
        .frame(maxWidth: 280)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: Notation field (editable, same pattern as Timer brick)

    private var notationField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Label this gate", text: $data.notation)
                .font(.system(size: 18, weight: .semibold))
                .textFieldStyle(.plain)
                .submitLabel(.done)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Large operator glyph

    private var glyphFace: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.08))
            Circle()
                .stroke(Color.orange.opacity(0.6), lineWidth: 2)

            Text(gateType.textGlyph ?? "?")
                .font(.system(size: 72, weight: .semibold, design: .serif))
                .foregroundStyle(Color.orange)
        }
        .frame(width: 140, height: 140)
    }

    // MARK: Gate name + family label

    private var gateNameLabel: some View {
        VStack(spacing: 2) {
            Text(gateType.displayName)
                .font(.title3)
                .fontWeight(.bold)
            Text("Logic gate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }
}

#Preview {
    GateBrickView(
        data: GateBrickData(gateType: .andGate, notation: "Both prep done")
    )
    .modelContainer(for: GateBrickData.self, inMemory: true)
    .padding()
}
