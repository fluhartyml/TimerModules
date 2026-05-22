// MARK: - CPMNotificationScheduler
//
// Schedules iOS local notifications (UNUserNotificationCenter) for
// CPM events. Per the locked Section J: every port firing logs and
// notifies by default; per-event Notify toggle suppresses the
// notification without suppressing the log.
//
// Phase 7 ships scheduling for .oneOff CPMEvents — the only
// recurrence mode whose firing date is fully resolved in Phase 4.
// The other three modes (ordinalWeekday, lastDayOfMonth, everyNMonths)
// resolve in later iterations when their per-mode editors arrive.
// Until then those events compute nil nextFiringDate and skip
// scheduling.
//
// Notification identifier scheme: "cpm-event-{event.id.uuidString}"
// — one outstanding scheduled request per CPMEvent. Re-scheduling
// removes the previous request first to avoid duplicates.

import Foundation
import UserNotifications

@MainActor
enum CPMNotificationScheduler {

    /// Prefix for the iOS notification identifier of every scheduled
    /// CPM firing. Plus the event's UUID makes each request uniquely
    /// addressable for cancellation / replacement.
    private static let identifierPrefix = "cpm-event-"

    /// Ask the user for permission to deliver local notifications.
    /// Idempotent — calling repeatedly is safe; the OS just returns
    /// the existing grant.
    static func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Permission errors are visible via Settings → Notifications;
            // no need to surface here. Per the locked fail-safe principle:
            // stop / preserve / surface, never workaround.
        }
    }

    /// Schedule (or re-schedule) an iOS notification for the given
    /// CPMEvent. Removes any previous request for the same event id
    /// first so re-saving doesn't leave stale duplicates.
    ///
    /// No-op when:
    ///   • event.notifyEnabled is false (per-event Silent toggle)
    ///   • nextFiringDate() returns nil (mode not yet supported)
    ///   • computed fire date is in the past
    static func schedule(_ event: CPMEvent) {
        let center = UNUserNotificationCenter.current()
        let identifier = identifier(for: event)

        // Remove any prior scheduled request for this event so edits
        // don't stack.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard event.notifyEnabled else { return }
        guard let fireDate = nextFiringDate(for: event) else { return }
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = event.eventName.isEmpty ? "CPM event" : event.eventName
        if !event.briefDescription.isEmpty {
            content.body = event.briefDescription
        }
        content.sound = .default
        content.userInfo = [
            "eventId": event.id.uuidString,
            "ownerCPMId": event.ownerCPMId?.uuidString ?? ""
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request, withCompletionHandler: nil)
    }

    /// Cancel any pending notification for the event.
    static func cancel(_ event: CPMEvent) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: event)])
    }

    /// Stable notification identifier for an event. Encapsulated so
    /// scheduling + cancellation always use the same scheme.
    private static func identifier(for event: CPMEvent) -> String {
        identifierPrefix + event.id.uuidString
    }

    /// Resolve an event's next firing Date based on its locked
    /// recurrence mode. Returns nil for modes whose per-mode editors
    /// haven't shipped yet — those events stay un-scheduled until
    /// their mode is fully wired.
    static func nextFiringDate(for event: CPMEvent) -> Date? {
        let mode = CPMEventRecurrenceMode(rawValue: event.recurrenceModeRaw) ?? .oneOff
        switch mode {
        case .oneOff:
            return decodeOneOffDate(from: event.recurrenceParamsJSON)
        case .ordinalWeekday, .lastDayOfMonth, .everyNMonths:
            // Per-mode editors + resolvers ship in a later iteration.
            return nil
        }
    }

    private static func decodeOneOffDate(from json: String) -> Date? {
        struct OneOffParams: Codable { let date: Date }
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(OneOffParams.self, from: data).date
    }
}
