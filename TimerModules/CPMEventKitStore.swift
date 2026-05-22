// MARK: - CPMEventKitStore
//
// Wraps EKEventStore for the Calendar Processing Module's bidirectional
// Apple Calendar bridge (locked spec sections P + R).
//
// Read-all / write-own model:
//   • READ: CPM polls every calendar the user has granted access to
//     (work, personal, holidays, etc.). Read-only on user calendars.
//   • WRITE: CPM creates and writes to its OWN dedicated EKCalendar
//     named "TimerModulesCPM" (matching the lock in section R). All
//     CPM-authored events land there. Never modifies other calendars.
//
// Phase 5+6 ships the permission flow + write-calendar provisioning.
// Actual event matching / port firing / UNNotification scheduling
// lands in Phase 7.
//
// Apple holidays = SUGGESTION (locked Section H lookup). CPM does not
// give the OS holiday calendar gospel status — it's one source among
// many for the day-rhythm holiday detection that arrives in Phase 8.

import Foundation
import Combine
import EventKit

@MainActor
final class CPMEventKitStore: ObservableObject {

    /// The single shared store. EKEventStore is meant to be long-lived;
    /// re-creating it churns access caches.
    static let shared = CPMEventKitStore()

    let store = EKEventStore()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus

    /// Identifier of the CPM's dedicated write calendar
    /// (EKCalendar.calendarIdentifier). nil until createIfNeeded()
    /// finds or creates it. Persisted per-CPM via
    /// CPMBrickData.writeCalendarIdentifier rather than here — this
    /// store-level value is just a runtime cache for the most-recently
    /// resolved CPM calendar.
    @Published private(set) var cachedWriteCalendarIdentifier: String?

    private init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Static title used for CPM's dedicated calendar in Apple Calendar.
    /// Per the locked read-all / write-own model: any event CPM writes
    /// goes to a calendar with this title; CPM never touches calendars
    /// it didn't create.
    static let writeCalendarTitle = "TimerModulesCPM"

    /// Request full-access permission for both read and write. iOS 17+
    /// split EventKit auth into .fullAccess vs .writeOnly — CPM needs
    /// both directions (locked Section P), so .fullAccess is the right
    /// ask. On older iOS this maps to the legacy single-stage prompt.
    func requestAccess() async {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                _ = granted  // status flips via the OS notification
            } else {
                let granted = try await store.requestAccess(to: .event)
                _ = granted
            }
        } catch {
            // Permission errors are surfaced via authorizationStatus
            // refresh; no need to propagate.
        }
        refreshAuthorizationStatus()
    }

    /// Re-check the current EK auth status from the OS. Useful after
    /// the user toggles Settings → Privacy → Calendars while the app
    /// is suspended.
    func refreshAuthorizationStatus() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Whether the current authorization is sufficient for CPM's
    /// bidirectional bridge.
    var hasFullAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    /// Find an existing "TimerModulesCPM" calendar in the EKEventStore's
    /// local sources, or create one if absent. Returns the calendar's
    /// identifier on success. Throws if write permission is missing.
    @discardableResult
    func ensureWriteCalendar() throws -> String {
        guard hasFullAccess else {
            throw NSError(
                domain: "CPMEventKitStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Full EventKit access required to create the CPM write calendar."]
            )
        }

        // Look for an existing CPM calendar by title in any writable source.
        if let existing = store.calendars(for: .event).first(where: { $0.title == Self.writeCalendarTitle }) {
            cachedWriteCalendarIdentifier = existing.calendarIdentifier
            return existing.calendarIdentifier
        }

        // None found — create one. Prefer iCloud source so it syncs
        // across the user's devices; fall back to .local.
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.writeCalendarTitle
        calendar.cgColor = CGColor(red: 1.0, green: 0.61, blue: 0.70, alpha: 1.0)
        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            calendar.source = icloud
        } else if let local = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = local
        } else if let any = store.sources.first {
            calendar.source = any
        }

        try store.saveCalendar(calendar, commit: true)
        cachedWriteCalendarIdentifier = calendar.calendarIdentifier
        return calendar.calendarIdentifier
    }
}
