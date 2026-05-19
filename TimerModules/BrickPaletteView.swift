// MARK: - BrickPaletteView
//
// Horizontal strip of draggable brick tiles. User drags a tile out
// of the palette and drops it onto the Gantt canvas to create a
// new brick instance (roadmap Section 1 — composition model is
// user-Lego).
//
// All BrickType cases appear in the palette so the full v1.0
// vocabulary is visible from day one. Tiles for not-yet-wired-up
// types render at reduced opacity until the milestone that wires
// them lands (M3 logic gates, M4 PM types, M5 supplemental).

import SwiftUI

struct BrickPaletteView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            paletteHeader

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(BrickType.Family.allCases, id: \.self) { family in
                        familySection(family)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(.regularMaterial)
    }

    private var paletteHeader: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)
            Text("Brick palette")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Drag a brick onto the canvas below")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func familySection(_ family: BrickType.Family) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(family.displayName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                ForEach(BrickType.allCases.filter { $0.family == family }) { type in
                    paletteTile(type)
                }
            }
        }
    }

    private func paletteTile(_ type: BrickType) -> some View {
        VStack(spacing: 4) {
            Image(systemName: type.symbolName)
                .font(.system(size: 22))
                .foregroundStyle(type.isWiredUp ? Color.accentColor : Color.secondary)
            Text(type.displayName)
                .font(.caption)
                .foregroundStyle(type.isWiredUp ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    type.isWiredUp
                        ? Color.accentColor.opacity(0.35)
                        : Color.secondary.opacity(0.2),
                    lineWidth: 1
                )
        )
        .opacity(type.isWiredUp ? 1.0 : 0.45)
        .draggable(type) {
            // Drag preview
            VStack(spacing: 4) {
                Image(systemName: type.symbolName)
                    .font(.system(size: 22))
                Text(type.displayName).font(.caption)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    BrickPaletteView()
        .frame(height: 160)
}
