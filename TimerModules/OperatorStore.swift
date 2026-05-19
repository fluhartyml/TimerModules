import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class OperatorStore {
    @ObservationIgnored private let modelContext: ModelContext
    var items: [OperatorItem]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.items = []
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<OperatorItem>(
            sortBy: [SortDescriptor(\.updatedDate, order: .reverse)]
        )
        do {
            self.items = try modelContext.fetch(descriptor)
        } catch {
            self.items = []
        }
        deduplicateByID()
        WidgetSnapshotPublisher.publish(from: self)
    }

    /// Removes duplicate records that share the same logical `id`. Duplicates appear
    /// when populate runs on multiple devices before CloudKit sync settles — SwiftData
    /// has no unique constraint on `id` at the schema level, so it accepts both inserts
    /// and CloudKit merges them. This sweep keeps the most-recently-updated copy per id
    /// and deletes the rest. Idempotent: runs on every refresh, no-op when no dupes.
    private func deduplicateByID() {
        let grouped = Dictionary(grouping: items, by: { $0.id })
        var didDelete = false
        for (_, group) in grouped where group.count > 1 {
            let sorted = group.sorted { $0.updatedDate > $1.updatedDate }
            for duplicate in sorted.dropFirst() {
                modelContext.delete(duplicate)
                didDelete = true
            }
        }
        if didDelete {
            try? modelContext.save()
            // Re-fetch to drop the deleted instances from `items` without re-entering refresh().
            let descriptor = FetchDescriptor<OperatorItem>(
                sortBy: [SortDescriptor(\.updatedDate, order: .reverse)]
            )
            self.items = (try? modelContext.fetch(descriptor)) ?? items.filter { !$0.isDeleted }
        }
    }

    // MARK: - Lookup

    func item(id: UUID) -> OperatorItem? {
        items.first(where: { $0.id == id })
    }

    // MARK: - CRUD

    func add(_ item: OperatorItem) {
        modelContext.insert(item)
        log(.created, on: item, details: item.title)
        try? modelContext.save()
        syncToEventKit(item)
        refresh()
    }

    func update(_ updated: OperatorItem) {
        updated.updatedDate = Date()
        log(.edited, on: updated, details: updated.title)
        try? modelContext.save()
        syncToEventKit(updated)
        refresh()
    }

    func delete(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        if let eventID = target.eventIdentifier {
            EventKitStore.shared.deleteEvent(identifier: eventID)
        }
        if let reminderID = target.reminderIdentifier {
            EventKitStore.shared.deleteReminder(identifier: reminderID)
        }
        modelContext.delete(target)
        try? modelContext.save()
        refresh()
    }

    private func syncToEventKit(_ item: OperatorItem) {
        // Calendar sync: any record with a dueDate
        if item.dueDate != nil && EventKitStore.shared.calendarsAuthorized {
            if let id = EventKitStore.shared.upsertEvent(for: item) {
                item.eventIdentifier = id
                try? modelContext.save()
            }
        } else if item.dueDate == nil, let oldID = item.eventIdentifier {
            EventKitStore.shared.deleteEvent(identifier: oldID)
            item.eventIdentifier = nil
            try? modelContext.save()
        }

        // Reminders sync: task-type records
        if item.type == .task && EventKitStore.shared.remindersAuthorized {
            if let id = EventKitStore.shared.upsertReminder(for: item) {
                item.reminderIdentifier = id
                try? modelContext.save()
            }
        }
    }

    func togglePin(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        target.pinned.toggle()
        target.updatedDate = Date()
        log(target.pinned ? .pinned : .unpinned, on: target)
        try? modelContext.save()
        refresh()
    }

    func toggleSecure(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        target.isSecure.toggle()
        target.updatedDate = Date()
        try? modelContext.save()
        refresh()
    }

    /// Log a user-initiated CRM interaction (call / message / email / meeting / note)
    /// against a person record. Surfaces in the record's activity log alongside
    /// system events, distinguished by isInteraction.
    func logInteraction(kind: ActivityKind, on item: OperatorItem, summary: String) {
        guard kind.isInteraction else { return }
        log(kind, on: item, details: summary)
        item.updatedDate = Date()
        try? modelContext.save()
        refresh()
    }

    // MARK: - Access grants (record sharing)

    /// Grant access to a record. If a grant for the same person already exists,
    /// updates the permission level. Otherwise inserts a new grant.
    func grantAccess(to recordID: UUID, person personID: UUID, permission: AccessPermission) {
        guard let target = items.first(where: { $0.id == recordID }) else { return }
        var grants = target.accessGrants
        if let idx = grants.firstIndex(where: { $0.personID == personID }) {
            grants[idx].permission = permission
        } else {
            grants.append(AccessGrant(personID: personID, permission: permission))
        }
        target.accessGrants = grants
        target.updatedDate = Date()
        try? modelContext.save()
        refresh()
    }

    /// Revoke a specific person's access to a single record.
    func revokeAccess(to recordID: UUID, person personID: UUID) {
        guard let target = items.first(where: { $0.id == recordID }) else { return }
        var grants = target.accessGrants
        grants.removeAll { $0.personID == personID }
        target.accessGrants = grants
        target.updatedDate = Date()
        try? modelContext.save()
        refresh()
    }

    /// Wholesale revoke — remove the person from every record's access list.
    /// Used from the per-Person detail view when the owner wants to fully
    /// uninvite someone from all shared content.
    func revokeAllAccess(person personID: UUID) {
        for item in items where item.accessGrants.contains(where: { $0.personID == personID }) {
            var grants = item.accessGrants
            grants.removeAll { $0.personID == personID }
            item.accessGrants = grants
            item.updatedDate = Date()
        }
        try? modelContext.save()
        refresh()
    }

    /// All records the given person currently has access to.
    func recordsShared(with personID: UUID) -> [OperatorItem] {
        items.filter { item in
            item.accessGrants.contains(where: { $0.personID == personID })
        }
        .sorted { $0.updatedDate > $1.updatedDate }
    }

    func toggleArchive(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        target.archived.toggle()
        target.updatedDate = Date()
        log(target.archived ? .archived : .unarchived, on: target)
        try? modelContext.save()
        refresh()
    }

    private func log(_ kind: ActivityKind, on item: OperatorItem, details: String = "") {
        let event = ActivityEvent(kind: kind, details: details)
        modelContext.insert(event)
        event.owner = item
        if item.events == nil {
            item.events = [event]
        } else {
            item.events?.append(event)
        }
    }

    // MARK: - Attachments

    func attach(_ attachment: Attachment, to item: OperatorItem) {
        modelContext.insert(attachment)
        attachment.owner = item
        if item.attachments == nil {
            item.attachments = [attachment]
        } else {
            item.attachments?.append(attachment)
        }
        item.updatedDate = Date()
        log(.attachmentAdded, on: item, details: attachment.originalName)
        try? modelContext.save()
        refresh()
    }

    func deleteAttachment(_ attachment: Attachment) {
        if let owner = attachment.owner {
            owner.attachments?.removeAll { $0.id == attachment.id }
            owner.updatedDate = Date()
            log(.attachmentRemoved, on: owner, details: attachment.originalName)
        }
        modelContext.delete(attachment)
        try? modelContext.save()
        refresh()
    }

    // MARK: - Timers

    func startTimer(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        guard target.type == .timer else { return }
        if target.runningSince == nil {
            target.runningSince = Date()
            target.updatedDate = Date()
            try? modelContext.save()

            // Schedule a system-level AlarmKit countdown if the timer has a target duration
            if let duration = target.alarmTargetSeconds, duration > 0 {
                Task { @MainActor in
                    if let alarmID = await AlarmKitManager.shared.scheduleTimer(for: target, duration: duration) {
                        target.alarmIdentifier = alarmID.uuidString
                        try? self.modelContext.save()
                        self.refresh()
                    }
                }
            }
            refresh()
        }
    }

    func stopTimer(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        guard target.type == .timer else { return }
        if let started = target.runningSince {
            target.accumulatedSeconds += Date().timeIntervalSince(started)
            target.runningSince = nil
            target.updatedDate = Date()

            // Cancel any system-level AlarmKit countdown tied to this timer
            if let alarmIDString = target.alarmIdentifier,
               let alarmID = UUID(uuidString: alarmIDString) {
                AlarmKitManager.shared.cancelTimer(id: alarmID)
                target.alarmIdentifier = nil
            }

            try? modelContext.save()
            refresh()
        }
    }

    func resetTimer(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        guard target.type == .timer else { return }
        target.accumulatedSeconds = 0
        target.runningSince = nil
        target.updatedDate = Date()
        try? modelContext.save()
        refresh()
    }

    func linkTimer(_ timerID: UUID, toRecord recordID: UUID?) {
        guard let target = items.first(where: { $0.id == timerID }) else { return }
        target.linkedRecordID = recordID
        target.updatedDate = Date()
        try? modelContext.save()
        refresh()
    }

    // MARK: - Sample data

    /// Adds any missing sample records back into the store and refreshes dates on
    /// existing sample records so re-populate always anchors to today (no stale
    /// "Sun May 10 shows first" artifacts from a populate run days ago).
    /// User edits to title/body/status/tags are preserved; only the date scaffolding
    /// regenerates on each call.
    @discardableResult
    func populateSampleRecords() -> (inserted: Int, refreshed: Int) {
        let existingByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var inserted = 0
        var refreshed = 0
        for sample in SampleData.allSamples() {
            if let existing = existingByID[sample.id] {
                existing.createdDate = sample.createdDate
                existing.updatedDate = sample.updatedDate
                existing.dueDate = sample.dueDate
                refreshed += 1
            } else {
                modelContext.insert(sample)
                log(.created, on: sample, details: sample.title)
                inserted += 1
            }
        }
        try? modelContext.save()
        refresh()
        attachSampleAssetsIfNeeded()
        return (inserted, refreshed)
    }

    /// Bundles a placeholder image with the Property Photo Set sample record so the
    /// Media detail view has real content instead of an empty attachments section.
    /// Self-healing: detects any stale prior-version placeholder by originalName and
    /// replaces it with fresh NSDataAsset bytes (raw bundle PNGs were CGBI-optimized
    /// in older builds — Quick Look couldn't render them). User-added attachments
    /// are left alone.
    private func attachSampleAssetsIfNeeded() {
        let propertyPhotoSetID = SampleData.propertyPhotoSetID
        guard let record = items.first(where: { $0.id == propertyPhotoSetID }) else { return }

        let placeholderName = "Property Yard Diagram.png"
        let existing = record.attachments ?? []

        // Remove any prior placeholder so the next attach lands fresh CGBI-free bytes.
        for old in existing where old.originalName == placeholderName {
            AttachmentStorage.delete(filename: old.filename)
            modelContext.delete(old)
        }

        // If user-added (non-placeholder) attachments are present, don't re-add ours.
        let userAdded = existing.filter { $0.originalName != placeholderName }
        guard userAdded.isEmpty else { return }

        guard let asset = NSDataAsset(name: "PropertyYardDiagram") else { return }
        do {
            let info = try AttachmentStorage.write(data: asset.data, suggestedExtension: "png")
            let attachment = Attachment(
                filename: info.filename,
                originalName: placeholderName,
                kind: .image
            )
            attach(attachment, to: record)
        } catch {
            // Silent — sample populate completes without the placeholder.
        }
    }

    func runningTimers() -> [OperatorItem] {
        items.filter { $0.type == .timer && $0.runningSince != nil && !$0.archived && !$0.isSecure }
    }

    /// Records the user has flagged as secure — only visible inside Vault > Secure Records.
    /// Hidden from every native module and from global search.
    var secureRecords: [OperatorItem] {
        items.filter { !$0.archived && $0.isSecure }
            .sorted { $0.updatedDate > $1.updatedDate }
    }

    // MARK: - Search

    /// Global search across non-archived, non-Vault records.
    /// Vault items are excluded — they only appear in searches launched from inside the Vault.
    func search(_ query: String) -> [OperatorItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let q = trimmed.lowercased()
        return items.filter { item in
            guard !item.archived else { return false }
            guard !item.isSecure else { return false }
            guard !item.type.isVaultOnly else { return false }
            if item.title.lowercased().contains(q) { return true }
            if item.subtitle.lowercased().contains(q) { return true }
            if item.body.lowercased().contains(q) { return true }
            if item.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
            if let related = item.relatedSystem, related.lowercased().contains(q) { return true }
            if item.type.label.lowercased().contains(q) { return true }
            return false
        }
        .sorted { $0.updatedDate > $1.updatedDate }
    }

    // MARK: - Section semantics
    //
    // Pin = "show on dashboard."
    // Date = "show on date sections regardless of pin."
    // Sparse rule = if a typed section has fewer than 2 pinned records,
    //               include the unpinned ones too so the section isn't empty/lonely.
    // Inbox = unpinned, undated, not surfaced anywhere else.

    private static let typedSectionTypes: Set<ItemType> = [.appliance, .homeSystem, .person, .project]

    private func typedSection(of types: Set<ItemType>) -> [OperatorItem] {
        let inScope = items.filter { !$0.archived && !$0.isSecure && types.contains($0.type) }
        let pinned = inScope.filter { $0.pinned }
        return pinned.count < 2 ? inScope : pinned
    }

    var today: [OperatorItem] {
        let cal = Calendar.current
        return items.filter { item in
            guard !item.archived else { return false }
            guard !item.isSecure else { return false }
            guard let due = item.dueDate else { return false }
            return cal.isDateInToday(due) || due < Date()
        }
    }

    /// Records due strictly today (not overdue).
    var scheduleToday: [OperatorItem] {
        let cal = Calendar.current
        return items.filter { item in
            guard !item.archived else { return false }
            guard !item.isSecure else { return false }
            guard let due = item.dueDate else { return false }
            return cal.isDateInToday(due)
        }
        .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    /// Records whose due date has passed.
    var expired: [OperatorItem] {
        let cal = Calendar.current
        return items.filter { item in
            guard !item.archived else { return false }
            guard !item.isSecure else { return false }
            guard item.status != .complete else { return false }
            guard let due = item.dueDate else { return false }
            return due < Date() && !cal.isDateInToday(due)
        }
        .sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
    }

    /// Records with status == .waiting (regardless of date).
    var waiting: [OperatorItem] {
        items.filter { !$0.archived && !$0.isSecure && $0.status == .waiting }
            .sorted { $0.updatedDate > $1.updatedDate }
    }

    /// Top-level Pinned section: pinned records whose type doesn't have its own typed section.
    var topLevelPinned: [OperatorItem] {
        items.filter {
            $0.pinned && !$0.archived && !$0.isSecure && !Self.typedSectionTypes.contains($0.type)
        }
    }

    var homeSystems: [OperatorItem] {
        typedSection(of: [.appliance, .homeSystem])
    }

    var people: [OperatorItem] {
        typedSection(of: [.person])
    }

    var projects: [OperatorItem] {
        typedSection(of: [.project])
    }

    var upcoming: [OperatorItem] {
        let now = Date()
        let cal = Calendar.current
        return items
            .filter { !$0.archived && !$0.isSecure }
            .filter { item in
                guard let due = item.dueDate else { return false }
                return due > now && !cal.isDateInToday(due)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var recentlyUpdated: [OperatorItem] {
        items
            .filter { !$0.archived && !$0.isSecure }
            .sorted { $0.updatedDate > $1.updatedDate }
            .prefix(5)
            .map { $0 }
    }

    /// Item types that have a dedicated sidebar/tab module — surfaced by those
    /// modules rather than by Inbox. Keep in sync with MacShellView /
    /// IPadShellView destination defaultType mapping.
    private static let homedTypes: Set<ItemType> = [
        .task, .secureNote, .media, .transcription,
        .homeSystem, .maintenance, .project, .person, .timer, .property
    ]

    /// Inbox: untriaged orphans — items the user hasn't yet pinned, scheduled,
    /// tagged, or placed into a module. Catches anything that escapes triage so
    /// nothing is silently lost.
    var inbox: [OperatorItem] {
        let surfaced: Set<UUID> = Set(
            homeSystems.map { $0.id }
            + people.map { $0.id }
            + projects.map { $0.id }
            + topLevelPinned.map { $0.id }
        )
        return items.filter { item in
            guard !item.archived else { return false }
            guard !item.isSecure else { return false }
            guard !item.pinned else { return false }
            guard item.dueDate == nil else { return false }
            guard item.tags.isEmpty else { return false }
            guard !Self.homedTypes.contains(item.type) else { return false }
            return !surfaced.contains(item.id)
        }
    }
}
