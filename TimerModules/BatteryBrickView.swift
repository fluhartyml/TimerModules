// MARK: - BatteryBrickView
//
// 1×1 passive readout of the system battery level.
//
// Locked design from Master Design Spec 12.11:
//   • iPhone/iPad: shows the current battery percentage from
//     UIDevice.current.batteryLevel.
//   • Mac variant: shakedown will surface what to show (laptop has
//     battery, desktop doesn't). For v1.0 we display "AC" with a
//     power-plug glyph; shakedown can refine.
//   • NO trace I/O in v1.0.

import SwiftUI
import SwiftData
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct BatteryBrickView: View {
    @Bindable var data: BatteryBrickData

    var onEditNoteTapped: () -> Void = {}

    private let cellSize: CGFloat = 60

    /// Tick to refresh the displayed value periodically. iOS posts
    /// notifications when battery level changes; we also poll every
    /// 30 seconds as a fallback.
    @State private var sample: BatteryReading = BatteryReading()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Image(systemName: sample.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(sample.color)
                Text(sample.label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(sample.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: cellSize, height: cellSize)
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
        .frame(width: cellSize, height: cellSize)
        .onAppear { refresh() }
        .onReceive(ticker) { _ in refresh() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery: \(sample.label)")
    }

    private func refresh() {
        sample = BatteryReading.current()
    }
}

// MARK: - BatteryReading (platform shim)

private struct BatteryReading {
    var symbol: String = "battery.50"
    var label: String = "--"
    var color: Color = Color.secondary

    static func current() -> BatteryReading {
        var r = BatteryReading()

        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel    // 0.0...1.0 or -1.0 if unknown
        let state = UIDevice.current.batteryState
        if level < 0 {
            r.symbol = "battery.0"
            r.label = "--"
            r.color = Color.secondary
        } else {
            let pct = Int(round(level * 100))
            r.label = "\(pct)%"
            // Symbol by remaining %.
            switch pct {
            case 0..<10:   r.symbol = "battery.0"
            case 10..<35:  r.symbol = "battery.25"
            case 35..<60:  r.symbol = "battery.50"
            case 60..<85:  r.symbol = "battery.75"
            default:       r.symbol = "battery.100"
            }
            // Color: red if low, green if charging, amber otherwise.
            if state == .charging || state == .full {
                r.color = Color.green
            } else if pct < 20 {
                r.color = Color.red
            } else {
                r.color = Color(red: 1.0, green: 0.82, blue: 0.35)
            }
        }
        #else
        // Mac fallback for v1.0 — per Master Design Spec 12.11 the
        // Mac variant is a shakedown question. Show a generic power
        // icon and "AC" label until shakedown surfaces the right UX.
        r.symbol = "powerplug.fill"
        r.label = "AC"
        r.color = Color.green
        #endif

        return r
    }
}
