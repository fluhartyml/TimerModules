// MARK: - LogWindowID
//
// Codable + Hashable payload identifying which chart's log
// should open in a new window. Used by SwiftUI's openWindow
// environment + a WindowGroup(for: LogWindowID.self) scene
// declared in TimerModulesApp.
//
// Per Michael 2026-05-19: the summary log popup on Mac needs
// traffic lights, drag-to-move, and a close button. The sheet
// presentation doesn't provide any of those. Opening the log
// as its own SwiftUI Window does — every Mac window gets the
// standard chrome for free.

import Foundation

struct LogWindowID: Codable, Hashable {
    let chartId: UUID
    let chartName: String
}
