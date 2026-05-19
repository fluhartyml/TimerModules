import Foundation

/// Reads pending-share entries written by OPerationsHOSShare into the App Group
/// container and converts them into Inbox OperatorItem records on app launch.
/// Clears the file after a successful read so entries aren't duplicated.
///
/// Pairs with OPerationsHOSShare/ShareViewController.swift on the writer side.
enum PendingShareConsumer {
    private static let appGroupID = "group.com.ChatGPT.OPerationsHOS"
    private static let pendingFilename = "pending-shares.json"

    /// Drain all pending-share entries and create OperatorItem records on the
    /// provided store. Each entry becomes a note-typed record in the Inbox flow
    /// (no module home, no tags, no due date — Inbox's orphan criteria pick it up).
    @MainActor
    static func consume(into store: OperatorStore) {
        guard let url = pendingFileURL() else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Malformed file — remove it so it doesn't keep failing.
            try? FileManager.default.removeItem(at: url)
            return
        }

        for entry in entries {
            let title = (entry["title"] as? String) ?? "Shared item"
            let body = (entry["body"] as? String) ?? ""
            let source = entry["source"] as? String
            let timestamp = (entry["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()

            let item = OperatorItem(
                title: title,
                subtitle: "",
                body: body,
                type: .note,
                status: .open,
                priority: .normal,
                createdDate: timestamp,
                updatedDate: timestamp,
                dueDate: nil,
                pinned: false,
                archived: false,
                isSecure: false,
                tags: [],
                relatedSystem: nil,
                source: source?.isEmpty == false ? source : nil
            )
            store.add(item)
        }

        // Clear the file after successful drain.
        try? FileManager.default.removeItem(at: url)
    }

    private static func pendingFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(pendingFilename)
    }
}
