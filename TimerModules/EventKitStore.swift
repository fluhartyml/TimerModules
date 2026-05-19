import Foundation
import EventKit
import Observation

@MainActor
@Observable
final class EventKitStore {
    static let shared = EventKitStore()

    private let store = EKEventStore()
    private let dedicatedCalendarTitle = "OPerationsHOS"
    private let dedicatedReminderListTitle = "OPerationsHOS"

    var calendarsAuthorized: Bool = false
    var remindersAuthorized: Bool = false
    var lastError: String?

    private init() {
        refreshAuthorizationState()
    }

    // MARK: - Authorization

    func refreshAuthorizationState() {
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        let remStatus = EKEventStore.authorizationStatus(for: .reminder)
        calendarsAuthorized = (calStatus == .fullAccess || calStatus == .authorized)
        remindersAuthorized = (remStatus == .fullAccess || remStatus == .authorized)
    }

    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            calendarsAuthorized = granted
            return granted
        } catch {
            lastError = error.localizedDescription
            calendarsAuthorized = false
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToReminders()
            remindersAuthorized = granted
            return granted
        } catch {
            lastError = error.localizedDescription
            remindersAuthorized = false
            return false
        }
    }

    // MARK: - Dedicated calendar

    /// Returns the dedicated OPerationsHOS calendar, creating it if needed.
    func dedicatedCalendar() -> EKCalendar? {
        guard calendarsAuthorized else { return nil }

        if let existing = store.calendars(for: .event).first(where: { $0.title == dedicatedCalendarTitle }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = dedicatedCalendarTitle
        calendar.cgColor = CGColor(red: 0, green: 0.48, blue: 1, alpha: 1) // OPerationsHOS blue

        // Pick the user's iCloud source if available; otherwise local.
        let sources = store.sources
        if let icloud = sources.first(where: { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }) {
            calendar.source = icloud
        } else if let local = sources.first(where: { $0.sourceType == .local }) {
            calendar.source = local
        } else if let any = sources.first {
            calendar.source = any
        } else {
            return nil
        }

        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Dedicated reminders list

    func dedicatedReminderList() -> EKCalendar? {
        guard remindersAuthorized else { return nil }

        if let existing = store.calendars(for: .reminder).first(where: { $0.title == dedicatedReminderListTitle }) {
            return existing
        }

        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = dedicatedReminderListTitle

        let sources = store.sources
        if let icloud = sources.first(where: { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }) {
            list.source = icloud
        } else if let local = sources.first(where: { $0.sourceType == .local }) {
            list.source = local
        } else if let any = sources.first {
            list.source = any
        } else {
            return nil
        }

        do {
            try store.saveCalendar(list, commit: true)
            return list
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Outbound: OperatorItem → EKEvent

    /// Creates or updates an EKEvent for the OperatorItem if it has a dueDate.
    /// Returns the event identifier so the OperatorItem can store it for future updates.
    @discardableResult
    func upsertEvent(for item: OperatorItem) -> String? {
        guard calendarsAuthorized,
              let dueDate = item.dueDate,
              let calendar = dedicatedCalendar() else { return nil }

        let event: EKEvent
        if let existingID = item.eventIdentifier,
           let existing = store.event(withIdentifier: existingID) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
        }

        event.title = item.title
        event.notes = item.body.isEmpty ? nil : item.body
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(3600) // 1 hour default
        event.isAllDay = false

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deleteEvent(identifier: String) {
        guard calendarsAuthorized,
              let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
    }

    // MARK: - Outbound: OperatorItem → EKReminder

    @discardableResult
    func upsertReminder(for item: OperatorItem) -> String? {
        guard remindersAuthorized,
              let list = dedicatedReminderList() else { return nil }

        let reminder: EKReminder
        if let existingID = item.reminderIdentifier,
           let existing = store.calendarItem(withIdentifier: existingID) as? EKReminder {
            reminder = existing
        } else {
            reminder = EKReminder(eventStore: store)
            reminder.calendar = list
        }

        reminder.title = item.title
        reminder.notes = item.body.isEmpty ? nil : item.body
        reminder.isCompleted = (item.status == .complete)

        if let due = item.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        } else {
            reminder.dueDateComponents = nil
        }

        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deleteReminder(identifier: String) {
        guard remindersAuthorized,
              let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try? store.remove(reminder, commit: true)
    }

    // MARK: - Inbound: read events / reminders from dedicated containers

    func eventsInDedicatedCalendar(from start: Date, to end: Date) -> [EKEvent] {
        guard calendarsAuthorized,
              let calendar = dedicatedCalendar() else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        return store.events(matching: predicate)
    }

    func remindersInDedicatedList() async -> [EKReminder] {
        guard remindersAuthorized,
              let list = dedicatedReminderList() else { return [] }
        let predicate = store.predicateForReminders(in: [list])
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func eventsInAllCalendars(from start: Date, to end: Date) -> [EKEvent] {
        guard calendarsAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }
}
