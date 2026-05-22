// MARK: - CPMBrickView
//
// SwiftUI view for one Calendar Processing Module (CPM) brick on the
// Gantt canvas. Phase 2 scaffold: bare 4×4 working area with empty
// state. Smart Stack faces, dual glyph composition, title chrome,
// and EventKit wiring arrive in later phases per the locked build
// order ("get the 4×4 working module in place first").
//
// Locked spec lives in
// TimerModules-Brain-Module-Refinement-2026-05-22.html.
// Per the locked widget/container distinction (Section "Locked So Far"):
//   • This 4×4 view IS the widget. Same body renders in an iOS Home
//     Screen widget extension post-v1.0.
//   • The 4×5 container (title chrome above) is an in-app holder added
//     by the canvas layer. Not implemented yet (Phase 9 polish).

import SwiftUI
import SwiftData

struct CPMBrickView: View {
    let data: CPMBrickData

    /// 4×4 canvas footprint, sized to the standard 60pt brick cell.
    /// 4 cells wide × 60pt + 3 inter-cell gaps × 4pt = 252pt.
    /// 4 cells tall × 60pt + 3 inter-cell gaps × 4pt = 252pt.
    /// Match these constants if the canvas grid metrics ever change.
    private static let cellSize: CGFloat = 60
    private static let cellGap: CGFloat = 4
    private static let columns: Int = 4
    private static let rows: Int = 4

    private static var bodyWidth: CGFloat {
        CGFloat(columns) * cellSize + CGFloat(columns - 1) * cellGap
    }
    private static var bodyHeight: CGFloat {
        CGFloat(rows) * cellSize + CGFloat(rows - 1) * cellGap
    }

    var body: some View {
        ZStack {
            // White body — the working surface. Matches the locked dual-glyph
            // base layer (Section B). Phase 9 polish wraps this in the
            // dual-glyph composition; Phase 2 ships the surface alone.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.25), lineWidth: 1)
                )

            VStack(spacing: 6) {
                // Brain SF Symbol placeholder. Phase 9 swaps this for the
                // canonical dual-glyph (white calendar + pink brain overlay
                // from brain-filled-twotone.png).
                Image(systemName: "brain")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(red: 0.78, green: 0.30, blue: 0.45))
                    .frame(width: Self.bodyWidth * 0.42)

                Text("CPM")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.78, green: 0.30, blue: 0.45))

                Text(eventCountSummary)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.black.opacity(0.6))
            }
            .padding(8)
        }
        .frame(width: Self.bodyWidth, height: Self.bodyHeight)
    }

    /// Empty-state summary line. Once Phase 4 adds the event grid this
    /// will be replaced by the Smart Stack face content.
    private var eventCountSummary: String {
        let count = data.events.count
        switch count {
        case 0:  return "no events yet"
        case 1:  return "1 event"
        default: return "\(count) events"
        }
    }
}
