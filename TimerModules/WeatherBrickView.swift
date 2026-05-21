// MARK: - WeatherBrickView
//
// 2×1 horizontal passive Weather readout backed by WeatherKit.
//
// Locked design from Master Design Spec 12.12. Reviewer attribution
// risk flagged at 12.13. Michael's call: ship anyway, refine in
// shakedown.
//
// Graceful degradation: if WeatherKit isn't entitled (e.g., during
// initial dev before the developer-portal config lands), the view
// still ships and just displays "—°" until a successful fetch.

import SwiftUI
import SwiftData
import CoreLocation

#if canImport(WeatherKit)
import WeatherKit
#endif

struct WeatherBrickView: View {
    @Bindable var data: WeatherBrickData

    var onEditNoteTapped: () -> Void = {}

    private let cellSize: CGFloat = 60
    private var width:  CGFloat { cellSize * 2 }
    private var height: CGFloat { cellSize }

    /// Tracks whether a WeatherKit fetch is in flight so we don't
    /// stack overlapping requests on rapid view appearances.
    @State private var isFetching: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Image(systemName: data.cachedSymbolName ?? "cloud")
                    .font(.system(size: 18))
                    .foregroundStyle(symbolColor)
                Text(data.displayedTemperature)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                    .lineLimit(1)
            }
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
        .task { await refreshIfNeeded() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather at \(data.locationLabel): \(data.displayedTemperature)")
    }

    private var symbolColor: Color {
        // Best-effort tint per the condition string. WeatherKit
        // returns enum cases like "clear", "cloudy", "rain", etc.
        guard let raw = data.cachedConditionRaw?.lowercased() else {
            return Color.secondary
        }
        if raw.contains("clear") || raw.contains("sunny") { return Color.yellow }
        if raw.contains("rain") || raw.contains("drizzle") || raw.contains("shower") {
            return Color.blue
        }
        if raw.contains("snow") || raw.contains("flurries") || raw.contains("sleet") {
            return Color.white
        }
        if raw.contains("cloud") || raw.contains("fog") || raw.contains("haze") {
            return Color.gray
        }
        return Color(red: 0.95, green: 0.80, blue: 0.35)
    }

    /// Fetch fresh data from WeatherKit if the cache is stale (older
    /// than 15 minutes) or empty. Silent failure on entitlement /
    /// network errors — the view falls back to the cached values
    /// (or the "—°" placeholder).
    private func refreshIfNeeded() async {
        let staleAfter: TimeInterval = 15 * 60
        if let last = data.cachedLastFetched,
           Date().timeIntervalSince(last) < staleAfter {
            return  // cache fresh
        }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        #if canImport(WeatherKit)
        if #available(iOS 16.0, macOS 13.0, *) {
            do {
                let loc = CLLocation(latitude: data.latitude, longitude: data.longitude)
                let weather = try await WeatherService.shared.weather(for: loc)
                let current = weather.currentWeather
                let tempC = current.temperature.converted(to: UnitTemperature.celsius).value
                let conditionRaw = String(describing: current.condition)
                let symbol = current.symbolName
                await MainActor.run {
                    data.cachedTempCelsius = tempC
                    data.cachedConditionRaw = conditionRaw
                    data.cachedSymbolName = symbol
                    data.cachedLastFetched = Date()
                    data.updatedDate = Date()
                }
            } catch {
                // Silent: cache stays as-is. Most common reason is
                // WeatherKit entitlement missing — Michael flagged
                // this risk at Master Design Spec 12.13.
            }
        }
        #endif
    }
}
