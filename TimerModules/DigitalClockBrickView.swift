// MARK: - DigitalClockBrickView
//
// 2×1 horizontal passive readout displaying current system time.
// Master Design Spec Section 12: HH:MM strip; no trace I/O.
//
// Refreshes via Timer.publish at 1Hz so the visible minute rollover
// is accurate. (Keeping a 1Hz tick rather than 1-minute is intentional
// so future-shakedown can add a seconds field with no architecture
// change.)

import SwiftUI
import SwiftData
import Combine

struct DigitalClockBrickView: View {
    @Bindable var data: DigitalClockBrickData

    var onEditNoteTapped: () -> Void = {}

    private let cellSize: CGFloat = 60
    private var width:  CGFloat { cellSize * 2 }
    private var height: CGFloat { cellSize }

    @State private var now: Date = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = data.use24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: now)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(formattedTime)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.95, green: 0.80, blue: 0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
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
        .onReceive(ticker) { newNow in
            now = newNow
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Digital clock showing \(formattedTime)")
    }
}
