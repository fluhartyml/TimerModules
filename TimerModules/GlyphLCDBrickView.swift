// MARK: - GlyphLCDBrickView
//
// 1×4 vertical column of single-glyph cells. Each cell is an "LED"
// per Master Design Spec 19.7: when port N fires, cell N lights up;
// others dim. Persists until another port fires.
//
// Configured glyphs are interpreted as SF Symbol names. If a string
// doesn't match an SF Symbol, it's rendered as text (graceful
// fallback for emoji or short labels).

import SwiftUI
import SwiftData

struct GlyphLCDBrickView: View {
    @Bindable var data: GlyphLCDBrickData
    @Environment(\.modelContext) private var modelContext

    var onEditNoteTapped: () -> Void = {}

    private let cellSize: CGFloat = 60
    private var width:  CGFloat { cellSize }
    private var height: CGFloat { cellSize * CGFloat(GlyphLCDBrickData.portCount) }

    /// LED-on color — bright amber.
    private var litColor: Color {
        Color(red: 1.0, green: 0.75, blue: 0.20)
    }

    /// LED-off color — dim amber ghost so the user can still see the
    /// configured glyph and recognize the cell, but it reads as "off."
    private var dimColor: Color {
        Color(red: 0.55, green: 0.42, blue: 0.18).opacity(0.55)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                ForEach(0..<GlyphLCDBrickData.portCount, id: \.self) { i in
                    cellView(index: i)
                }
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.75))
            )

            // Note glyph
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
        .frame(width: width, height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            data.currentPortIndex.flatMap { i in
                "Glyph LCD, port \(i + 1) lit"
            } ?? "Glyph LCD, no port lit"
        )
    }

    @ViewBuilder
    private func cellView(index i: Int) -> some View {
        let glyph = (i < data.glyphs.count) ? data.glyphs[i] : ""
        let isLit = (data.currentPortIndex == i)
        let color = isLit ? litColor : dimColor

        ZStack {
            // Try to render as SF Symbol; fall back to text rendering
            // if the symbol isn't found (this is how SwiftUI handles
            // unknown symbol names — they render as text).
            if glyph.isEmpty {
                // Empty slot — show a faint dot so the cell still
                // reads as occupied space.
                Image(systemName: "circle")
                    .foregroundStyle(color.opacity(0.3))
            } else if isSFSymbol(glyph) {
                Image(systemName: glyph)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(8)
            } else {
                Text(glyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: cellSize - 4, height: cellSize - 4)
    }

    /// Heuristic: SF Symbol names contain only ASCII letters/digits
    /// and periods/hyphens (e.g., "sun.max.fill"). Emoji or
    /// freeform text contain non-ASCII or spaces. This is not
    /// authoritative — at render time SwiftUI silently ignores
    /// unknown symbol names — but it lets us pick the right
    /// rendering path proactively.
    private func isSFSymbol(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        for ch in s {
            let scalar = ch.unicodeScalars.first!.value
            let isAlnum = (scalar >= 0x30 && scalar <= 0x39) ||
                          (scalar >= 0x41 && scalar <= 0x5A) ||
                          (scalar >= 0x61 && scalar <= 0x7A)
            let isPunct = (ch == "." || ch == "-")
            if !(isAlnum || isPunct) {
                return false
            }
        }
        return true
    }
}
