// MARK: - GateGlyphShape
//
// IEEE Std 91-1984 distinctive-shape gate hieroglyphs drawn as
// SwiftUI Paths (Michael 2026-05-20: "the fonts you need to use
// need to be recognisable hyroglyphs you can intuitively tell what
// the gate does"). Replaces the Unicode mathematical operators
// (∧ ∨ ¬ ⊕ ⊼ ⊽ ⊙) previously rendered as text characters in the
// gate card glyph face.
//
// The shapes are an implementation of the published IEEE 91
// standard, not a derivative of any specific font or library — the
// standard itself is public.
//
// Render with `.stroke(...)` for the schematic outline look. Each
// shape draws within the given rect; a 5:3 width-to-height aspect
// ratio produces the most balanced visual.

import SwiftUI

struct GateGlyphShape: Shape {
    let gateType: BrickType

    func path(in rect: CGRect) -> Path {
        switch gateType {
        case .andGate:   return andPath(in: rect)
        case .orGate:    return orPath(in: rect)
        case .notGate:   return notPath(in: rect)
        case .nandGate:  return nandPath(in: rect)
        case .norGate:   return norPath(in: rect)
        case .xorGate:   return xorPath(in: rect)
        case .xnorGate:  return xnorPath(in: rect)
        default:         return Path()
        }
    }

    // MARK: AND — flat back, semicircular front

    private func andPath(in rect: CGRect) -> Path {
        let arcR = rect.height / 2
        let bodyRight = rect.maxX - arcR
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: bodyRight, y: rect.minY))
        p.addArc(
            center: CGPoint(x: bodyRight, y: rect.midY),
            radius: arcR,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }

    // MARK: OR — concave back, pointed front

    private func orPath(in rect: CGRect) -> Path {
        let w = rect.width
        let leftBulge = w * 0.22
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.minX + w * 0.65, y: rect.minY)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.minX + w * 0.65, y: rect.maxY)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + leftBulge, y: rect.midY)
        )
        p.closeSubpath()
        return p
    }

    // MARK: NOT — triangle pointing right + inversion bubble

    private func notPath(in rect: CGRect) -> Path {
        let bubbleR = rect.height * 0.10
        let triEnd = rect.maxX - bubbleR * 2
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: triEnd, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        p.addEllipse(in: CGRect(
            x: triEnd,
            y: rect.midY - bubbleR,
            width: bubbleR * 2,
            height: bubbleR * 2
        ))
        return p
    }

    // MARK: NAND — AND + inversion bubble

    private func nandPath(in rect: CGRect) -> Path {
        let bubbleR = rect.height * 0.10
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width - bubbleR * 2,
            height: rect.height
        )
        var p = andPath(in: bodyRect)
        p.addEllipse(in: CGRect(
            x: bodyRect.maxX,
            y: rect.midY - bubbleR,
            width: bubbleR * 2,
            height: bubbleR * 2
        ))
        return p
    }

    // MARK: NOR — OR + inversion bubble

    private func norPath(in rect: CGRect) -> Path {
        let bubbleR = rect.height * 0.10
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width - bubbleR * 2,
            height: rect.height
        )
        var p = orPath(in: bodyRect)
        p.addEllipse(in: CGRect(
            x: bodyRect.maxX,
            y: rect.midY - bubbleR,
            width: bubbleR * 2,
            height: bubbleR * 2
        ))
        return p
    }

    // MARK: XOR — OR with an extra concave back-arc

    private func xorPath(in rect: CGRect) -> Path {
        let w = rect.width
        let extraOffset = w * 0.10
        let bodyRect = CGRect(
            x: rect.minX + extraOffset,
            y: rect.minY,
            width: rect.width - extraOffset,
            height: rect.height
        )
        var p = orPath(in: bodyRect)
        // Extra concave arc that parallels the OR body's back, drawn
        // as a separate open sub-path so a stroke renders it as the
        // recognizable second curve on the back of the XOR symbol.
        let extraStart = CGPoint(x: rect.minX, y: rect.minY)
        let extraEnd   = CGPoint(x: rect.minX, y: rect.maxY)
        let extraCtrl  = CGPoint(x: rect.minX + (w * 0.22), y: rect.midY)
        p.move(to: extraStart)
        p.addQuadCurve(to: extraEnd, control: extraCtrl)
        return p
    }

    // MARK: XNOR — XOR + inversion bubble

    private func xnorPath(in rect: CGRect) -> Path {
        let bubbleR = rect.height * 0.10
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width - bubbleR * 2,
            height: rect.height
        )
        var p = xorPath(in: bodyRect)
        p.addEllipse(in: CGRect(
            x: bodyRect.maxX,
            y: rect.midY - bubbleR,
            width: bubbleR * 2,
            height: bubbleR * 2
        ))
        return p
    }
}
