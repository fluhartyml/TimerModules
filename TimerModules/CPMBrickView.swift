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

    /// CPMEvents owned by this CPM, queried by foreign-key UUID.
    /// Matches the project's flat-model convention — see CPMEvent.ownerCPMId.
    @Query private var ownedEvents: [CPMEvent]

    /// Whether the Smart Stack detail sheet is currently presented.
    @State private var showDetail: Bool = false

    init(data: CPMBrickData) {
        self.data = data
        let cpmId = data.id
        _ownedEvents = Query(filter: #Predicate<CPMEvent> { $0.ownerCPMId == cpmId })
    }

    /// Canvas footprint constants. Per the locked Section "Locked So Far"
    /// widget vs container distinction (your call 2026-05-22):
    ///   • 4×4 CPM IS the widget — Apple-widget-size compliant. The
    ///     working surface (event grid, calendar grid, port roster, etc.)
    ///     occupies just the 4×4.
    ///   • The 4×5 outer holder adds the 5th-row title chrome on top.
    ///     Canvas-only — never ships as a widget.
    ///
    /// Standard brick cell is 60pt + 4pt inter-cell gap:
    ///   • bodyWidth   = 4 cells = 252pt
    ///   • bodyHeight  = 4 cells = 252pt (the widget face)
    ///   • titleHeight = 1 cell  = 60pt (the chrome above the widget)
    ///   • totalHeight = 252 + 4 + 60 = 316pt
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
    private static let titleHeight: CGFloat = cellSize
    private static var totalHeight: CGFloat {
        bodyHeight + cellGap + titleHeight
    }

    /// Pink + dark-pink colors locked for the dual-glyph composition
    /// (Section B of the spec). Matches the canonical
    /// brain-filled-twotone.png in Library/Reference-Docs.
    private static let darkPink = Color(red: 0.78, green: 0.30, blue: 0.45)
    private static let lightPink = Color(red: 1.0,  green: 0.61, blue: 0.70)
    private static let calendarHeaderRed = Color(red: 0.85, green: 0.22, blue: 0.20)

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: Self.cellGap) {
                titleChrome
                widgetBody
            }
            .frame(width: Self.bodyWidth, height: Self.totalHeight)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CPMDetailView(data: data)
        }
    }

    // MARK: Title chrome (locked Section A — 5th row above the 4×4)
    //
    // Canvas-only. The eventual iOS Home Screen widget extension will
    // render only the 4×4 widgetBody; this chrome row is not part of
    // that widget face.
    private var titleChrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.06))
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Self.darkPink)
                Text("Calendar Processing Module")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: Self.bodyWidth, height: Self.titleHeight)
    }

    // MARK: 4×4 widget body — dual-glyph composition (Section B)
    //
    // Locked dual-glyph: white calendar page (red header strip + black
    // grid + abstract day dots) with a pink brain overlapping it. This
    // is rendered live in SwiftUI rather than from the canonical PNG
    // (brain-filled-twotone.png in Library/Reference-Docs) so the
    // glyph scales cleanly at any size and avoids bundling the PNG
    // asset until the Phase 9 polish iteration that imports it.
    private var widgetBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.25), lineWidth: 1)
                )

            // Calendar base — red header strip + grid + day dots
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Self.calendarHeaderRed)
                    .frame(height: Self.bodyHeight * 0.16)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Pink brain overlay
            Image(systemName: "brain")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Self.lightPink)
                .frame(width: Self.bodyWidth * 0.78)
                .overlay(
                    Image(systemName: "brain")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Self.darkPink)
                        .frame(width: Self.bodyWidth * 0.78)
                        .blendMode(.normal)
                        .opacity(0.6)
                )

            // Event count badge in lower-right corner
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(eventCountSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.85))
                        )
                        .padding(8)
                }
            }
        }
        .frame(width: Self.bodyWidth, height: Self.bodyHeight)
    }

    /// Empty-state summary line. Once Phase 4 adds the event grid this
    /// will be replaced by the Smart Stack face content.
    private var eventCountSummary: String {
        switch ownedEvents.count {
        case 0:  return "no events yet"
        case 1:  return "1 event"
        default: return "\(ownedEvents.count) events"
        }
    }
}
