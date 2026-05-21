// MARK: - CalendarDateBrickView
//
// 2×1 horizontal passive readout of the current system date.
// Master Design Spec Section 12.10.

import SwiftUI
import SwiftData
import Combine

struct CalendarDateBrickView: View {
    @Bindable var data: CalendarDateBrickData

    var onEditNoteTapped: () -> Void = {}

    private let cellSize: CGFloat = 60
    private var width:  CGFloat { cellSize * 2 }
    private var height: CGFloat { cellSize }

    @State private var now: Date = Date()
    // 60-second tick is plenty for a date display.
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var formattedDate: String {
        let formatter = DateFormatter()
        switch data.formatStyleRaw {
        case 1:  formatter.dateFormat = "M/d/yy"
        case 2:  formatter.dateFormat = "EEE MMM d"
        default: formatter.dateFormat = "MMM d EEE"   // "May 21 Thu"
        }
        return formatter.string(from: now)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(formattedDate)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.95, green: 0.80, blue: 0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 6)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.75))
                )

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
        .onReceive(ticker) { newNow in now = newNow }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calendar date: \(formattedDate)")
    }
}
