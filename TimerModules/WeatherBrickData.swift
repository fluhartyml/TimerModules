// MARK: - WeatherBrickData
//
// SwiftData @Model for one Weather module brick.
//
// Locked design from Master Design Spec 12.12 + 12.15:
//   • 2×1 horizontal — icon + temp ("☀ 78°").
//   • Requires WeatherKit (entitlement risk flagged at 12.13).
//   • Passive readout — polled by consumers via traces, never fires
//     on its own (12.15).
//   • NO trace I/O in v1.0 ships as a pure read-only display; the
//     polling model (12.15) is the post-shakedown extension.
//
// Default location: Surfside Beach, TX (~28.94, -95.28) — Michael's
// address per the apartment memory. User edits via context menu.

import Foundation
import SwiftData

@Model
final class WeatherBrickData {
    var id: UUID = UUID()
    var notation: String = "Weather"
    var note: String = ""

    /// Location used for the WeatherKit query.
    var latitude: Double = 28.94
    var longitude: Double = -95.28
    /// Human-readable location label shown in the UI / accessibility.
    var locationLabel: String = "Surfside Beach, TX"

    /// Cached most-recent fetch (so the view shows last-known values
    /// even before the next async fetch completes).
    var cachedTempCelsius: Double?
    var cachedConditionRaw: String?       // WeatherKit's WeatherCondition.rawValue
    var cachedSymbolName: String?         // SF Symbol name for the condition
    var cachedLastFetched: Date?

    /// Display temp in Fahrenheit (default) vs. Celsius.
    var displayInFahrenheit: Bool = true

    var order: Int = 0
    var column: Int = 0
    var ganttChartId: UUID?
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        notation: String = "Weather",
        note: String = "",
        latitude: Double = 28.94,
        longitude: Double = -95.28,
        locationLabel: String = "Surfside Beach, TX",
        cachedTempCelsius: Double? = nil,
        cachedConditionRaw: String? = nil,
        cachedSymbolName: String? = nil,
        cachedLastFetched: Date? = nil,
        displayInFahrenheit: Bool = true,
        order: Int = 0,
        column: Int = 0,
        ganttChartId: UUID? = nil,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.notation = notation
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.cachedTempCelsius = cachedTempCelsius
        self.cachedConditionRaw = cachedConditionRaw
        self.cachedSymbolName = cachedSymbolName
        self.cachedLastFetched = cachedLastFetched
        self.displayInFahrenheit = displayInFahrenheit
        self.order = order
        self.column = column
        self.ganttChartId = ganttChartId
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }

    /// Display temperature in the configured unit, with a degree
    /// symbol. Returns "—°" when no value is cached yet.
    var displayedTemperature: String {
        guard let c = cachedTempCelsius else { return "—°" }
        if displayInFahrenheit {
            let f = c * 9.0 / 5.0 + 32.0
            return "\(Int(round(f)))°"
        } else {
            return "\(Int(round(c)))°"
        }
    }
}
