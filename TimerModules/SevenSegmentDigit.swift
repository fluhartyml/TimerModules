// MARK: - SevenSegmentDigit
//
// Renders a single digit (0-9) in the classic 7-segment-display
// style — like a "don't walk" crosswalk countdown or an old digital
// clock readout. Used by DelayBrickView (Master Design Spec 18.5);
// will also be used by the post-v1.0 logic-lab 7-segment display
// module (Master Design Spec 21.4 captures the cosplay aesthetic).
//
// Segment layout (industry-standard "a through g"):
//
//      aaa
//     f   b
//     f   b
//      ggg
//     e   c
//     e   c
//      ddd
//
// Each digit lights specific segments. Lit = drawn in `litColor`;
// unlit segments are either omitted (default) or drawn faintly in
// `dimColor` for the "ghost" aesthetic.

import SwiftUI

struct SevenSegmentDigit: View {
    /// The digit to display (0-9). Out-of-range values draw nothing.
    let digit: Int

    /// Color of lit segments (the "on" LEDs). Defaults to amber.
    var litColor: Color = Color(red: 1.0, green: 0.75, blue: 0.20)

    /// Color of unlit-segment "ghosts" (the "off" LEDs). Set to
    /// `.clear` to omit unlit segments entirely. Defaults to clear.
    var dimColor: Color = .clear

    /// Stroke width as a fraction of the digit's smaller dimension.
    /// 0.16 looks roughly right for a 60pt cell.
    var strokeFraction: CGFloat = 0.16

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            // Digit drawn in an internal aspect ratio of ~1:2 (square
            // looks weird for 7-seg; portrait is more LED-like).
            let digitWidth = size * 0.55
            let digitHeight = size * 0.92
            let strokeWidth = size * strokeFraction
            let origin = CGPoint(
                x: (geo.size.width - digitWidth) / 2,
                y: (geo.size.height - digitHeight) / 2
            )

            ZStack {
                ForEach(Segment.allCases, id: \.self) { seg in
                    seg.path(
                        origin: origin,
                        width: digitWidth,
                        height: digitHeight,
                        stroke: strokeWidth
                    )
                    .fill(seg.isLit(forDigit: digit) ? litColor : dimColor)
                }
            }
        }
    }

    // MARK: Segment geometry

    /// The seven segments of a standard 7-segment display.
    enum Segment: String, CaseIterable {
        case a   // top horizontal
        case b   // top-right vertical
        case c   // bottom-right vertical
        case d   // bottom horizontal
        case e   // bottom-left vertical
        case f   // top-left vertical
        case g   // middle horizontal

        /// Which segments are lit for each digit (0-9).
        func isLit(forDigit d: Int) -> Bool {
            let map: [Int: Set<Segment>] = [
                0: [.a, .b, .c, .d, .e, .f],
                1: [.b, .c],
                2: [.a, .b, .g, .e, .d],
                3: [.a, .b, .g, .c, .d],
                4: [.f, .g, .b, .c],
                5: [.a, .f, .g, .c, .d],
                6: [.a, .f, .g, .e, .c, .d],
                7: [.a, .b, .c],
                8: [.a, .b, .c, .d, .e, .f, .g],
                9: [.a, .b, .c, .d, .f, .g],
            ]
            return map[d]?.contains(self) ?? false
        }

        /// Build the SwiftUI Path for this segment, given the
        /// bounding-box origin + dimensions + segment stroke width.
        /// Segments are drawn as horizontal/vertical "bars" with the
        /// pointed-cap shape typical of LED displays approximated
        /// here as rectangles (good enough at 60pt cell size).
        func path(origin: CGPoint, width w: CGFloat, height h: CGFloat, stroke s: CGFloat) -> Path {
            let x0 = origin.x
            let y0 = origin.y
            // The display is split into top half (a, b, f) and bottom
            // half (d, c, e), with middle (g) at the join.
            let midY = y0 + h / 2
            let bottomY = y0 + h

            switch self {
            case .a:  // top horizontal
                return barRect(x: x0 + s/2, y: y0, w: w - s, h: s)
            case .b:  // top-right vertical
                return barRect(x: x0 + w - s, y: y0 + s/2, w: s, h: h/2 - s)
            case .c:  // bottom-right vertical
                return barRect(x: x0 + w - s, y: midY + s/2, w: s, h: h/2 - s)
            case .d:  // bottom horizontal
                return barRect(x: x0 + s/2, y: bottomY - s, w: w - s, h: s)
            case .e:  // bottom-left vertical
                return barRect(x: x0, y: midY + s/2, w: s, h: h/2 - s)
            case .f:  // top-left vertical
                return barRect(x: x0, y: y0 + s/2, w: s, h: h/2 - s)
            case .g:  // middle horizontal
                return barRect(x: x0 + s/2, y: midY - s/2, w: w - s, h: s)
            }
        }

        private func barRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: min(w, h) * 0.25)
        }
    }
}
