// MARK: - CPMUserPreferences
//
// Single-instance SwiftData @Model that stores the user's circadian
// rhythm + day-type mapping + week-start convention. Captured during
// the Setup Assistant wizard (locked Section G) and edited piecemeal
// in app Settings thereafter.
//
// "Single-instance" enforced at the query layer — views fetch the
// first CPMUserPreferences row and create one if absent. Not enforced
// at the schema level so CloudKit migration is straightforward.
//
// Phase 8 ships the data shape. The actual Setup Assistant multi-step
// wizard UI iterates in a later commit; for now the model is read /
// written by Settings stubs and the defaults populate everything.

import Foundation
import SwiftData

@Model
final class CPMUserPreferences {

    /// Stable identifier (used to dedupe if multiple rows ever arrive
    /// via CloudKit sync race).
    var id: UUID = UUID()

    // MARK: Day phases (locked Section G)
    //
    // Stored as DateComponents-style minute-of-day integers (0-1439)
    // rather than full Dates — phase reference points are time-of-day
    // independent of which day. Foundation Calendar combines minutes
    // with the current date when an event needs an absolute fire time.

    /// Wake-up reference point, minute-of-day (default 06:00 = 360).
    var wakeMinute: Int = 360

    /// Productive-day start, minute-of-day (default 08:00 = 480).
    var productiveDayStartMinute: Int = 480

    /// Wind-down start, minute-of-day (default 21:00 = 1260).
    var windDownMinute: Int = 1260

    /// Bedtime / sleep start, minute-of-day (default 22:00 = 1320).
    var bedtimeMinute: Int = 1320

    // MARK: Day-type mapping (locked Section G, three-rhythm split)
    //
    // Each int is a Calendar.weekday value (1 = Sunday, 7 = Saturday).
    // workDays, midTempoDays, restDays partition the seven days of the
    // week. The Setup Assistant's checkbox row writes here.

    /// Days that follow the productive (workday) rhythm.
    /// Default: Mon-Fri (Calendar.weekday 2-6).
    var workDays: [Int] = [2, 3, 4, 5, 6]

    /// Days that follow the mid-tempo (errand / social) rhythm.
    /// Default: Saturday (7).
    var midTempoDays: [Int] = [7]

    /// Days that follow the rest rhythm. Default: Sunday (1).
    var restDays: [Int] = [1]

    // MARK: Week-start convention (locked Section H)
    //
    // Default uses the user's iOS locale. Stored as Calendar.weekday
    // value (1 = Sunday for US, 2 = Monday for ISO/Europe). Setup
    // Assistant can override.

    /// First day of the visible calendar week. Defaults to
    /// Calendar.current.firstWeekday at row-creation time.
    var firstWeekday: Int = Calendar.current.firstWeekday

    // MARK: Holiday source (locked Section H)
    //
    // Apple's locale holiday calendar is a SUGGESTION, never gospel.
    // User can override per-date inside CPM's own event grid or by
    // editing their iCal holiday entries.

    /// Whether CPM consults the user's locale iOS holiday calendar at
    /// all. Default true — turn off to treat every day as either
    /// work / mid / rest based on workDays/midTempoDays/restDays.
    var useIOSHolidayCalendar: Bool = true

    // MARK: Setup state

    /// Whether the user has completed the Setup Assistant wizard at
    /// least once. False until the user finishes the wizard or saves
    /// any preference manually. Used to drive the first-launch prompt.
    var hasCompletedSetupAssistant: Bool = false

    /// Bookkeeping.
    var createdDate: Date = Date()
    var updatedDate: Date = Date()

    init(
        id: UUID = UUID(),
        wakeMinute: Int = 360,
        productiveDayStartMinute: Int = 480,
        windDownMinute: Int = 1260,
        bedtimeMinute: Int = 1320,
        workDays: [Int] = [2, 3, 4, 5, 6],
        midTempoDays: [Int] = [7],
        restDays: [Int] = [1],
        firstWeekday: Int = Calendar.current.firstWeekday,
        useIOSHolidayCalendar: Bool = true,
        hasCompletedSetupAssistant: Bool = false,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.wakeMinute = wakeMinute
        self.productiveDayStartMinute = productiveDayStartMinute
        self.windDownMinute = windDownMinute
        self.bedtimeMinute = bedtimeMinute
        self.workDays = workDays
        self.midTempoDays = midTempoDays
        self.restDays = restDays
        self.firstWeekday = firstWeekday
        self.useIOSHolidayCalendar = useIOSHolidayCalendar
        self.hasCompletedSetupAssistant = hasCompletedSetupAssistant
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}

/// Classification of a single calendar day by the user's locked
/// rhythm mapping. Used by future event-firing logic to honor the
/// "weekend / holiday routine differs from weekday" lock (Section G).
enum CPMDayType: String, Codable {
    case work
    case midTempo
    case rest
}

extension CPMUserPreferences {
    /// Classify a Date according to the stored day-type mapping. Holiday
    /// detection (when useIOSHolidayCalendar is true) lives at the
    /// EventKit query layer and is not handled here.
    func dayType(for date: Date, calendar: Calendar = .current) -> CPMDayType {
        let weekday = calendar.component(.weekday, from: date)
        if workDays.contains(weekday) { return .work }
        if midTempoDays.contains(weekday) { return .midTempo }
        return .rest
    }
}
