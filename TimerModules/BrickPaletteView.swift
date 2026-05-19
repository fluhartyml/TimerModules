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
    /// Shared tap-to-wire state. When the user taps the Trace tile,
    /// we flip into "awaitingSource" mode and the GanttCanvasView
    /// handles the subsequent brick taps.
    @Bindable var wiring: WiringState

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
                ForEach(BrickType.allCases.filter { $0.family == family && $0.appearsInPalette }) { type in
                    paletteTile(type)
                }
            }
        }
    }

    @ViewBuilder
    private func paletteTile(_ type: BrickType) -> some View {
        if type == .trace {
            traceTile
        } else {
            draggableTile(type)
        }
    }

    /// The Trace tile uses tap-to-wire instead of drag-and-drop
    /// (M5.7). Tapping it puts the canvas into wiring mode where
    /// the user then taps source and destination bricks.
    private var traceTile: some View {
        let type = BrickType.trace
        let isActiveWiringTool = wiring.isWiring
        return VStack(spacing: 4) {
            tileGlyph(type)
                .frame(height: 26)
                .foregroundStyle(isActiveWiringTool ? Color.white : Color.accentColor)
            Text(type.displayName)
                .font(.caption)
                .foregroundStyle(isActiveWiringTool ? Color.white : Color.primary)
                .lineLimit(1)
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActiveWiringTool ? Color.accentColor : Color.clear)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(isActiveWiringTool ? 0 : 0.6), lineWidth: 1.5)
        )
        .onTapGesture {
            if wiring.isWiring {
                wiring.cancel()
            } else {
                wiring.startWiring()
            }
        }
    }

    private func draggableTile(_ type: BrickType) -> some View {
        VStack(spacing: 4) {
            tileGlyph(type)
                .frame(height: 26)
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
            VStack(spacing: 4) {
                tileGlyph(type)
                    .frame(height: 26)
                Text(type.displayName).font(.caption)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// Renders either an SF Symbol (most bricks) or a mathematical-
    /// operator text glyph (logic gates) depending on the BrickType.
    @ViewBuilder
    private func tileGlyph(_ type: BrickType) -> some View {
        if let symbolName = type.symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 22))
        } else if let glyph = type.textGlyph {
            Text(glyph)
                .font(.system(size: 24, weight: .semibold, design: .serif))
        } else {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 22))
        }
    }
}

#Preview {
    BrickPaletteView(wiring: WiringState())
        .frame(height: 160)
}
