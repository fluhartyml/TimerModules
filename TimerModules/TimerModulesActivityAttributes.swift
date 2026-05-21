// MARK: - TimerModulesActivityAttributes (main app target copy)
//
// Identical duplicate of the type defined in
// TimerModulesWidget/TimerModulesWidgetLiveActivity.swift. ActivityKit
// requires both the main app target (which starts/updates/ends the
// activity) and the widget extension target (which renders it) to
// have access to the SAME ActivityAttributes type.
//
// Filesystem-synced Xcode 16 project groups don't support a single
// shared Swift file across two targets without manual project-file
// edits; the canonical pragmatic workaround is to duplicate the
// definition. ActivityKit interoperates via Codable encoding, so as
// long as the field names + types match exactly across the two
// copies, the activity round-trips correctly.
//
// **Keep this file IN SYNC with the widget extension's copy.** Any
// change to ContentState fields must be applied to both files.

import Foundation

#if os(iOS) || os(visionOS)
import ActivityKit

@available(iOS 16.1, *)
struct TimerModulesActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var isPaused: Bool
        var isComplete: Bool
    }

    var chartName: String
    var timerNotation: String
}
#endif
