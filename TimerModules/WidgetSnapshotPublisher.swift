import Foundation
import WidgetKit

/// Main-app side of the widget snapshot pipeline. Writes a JSON snapshot to the
/// App Group container so the widget extension can read it. Mirrors the shape
/// of WidgetSnapshot in the OPerationsHOSWidgets target — keep them aligned.
struct WidgetSnapshotPublisher {
    private struct Snapshot: Codable {
        struct Row: Codable {
            let id: UUID
            let title: String
            let symbol: String
        }
        let today: [Row]
        let pinned: [Row]
        let inbox: [Row]
    }

    private static let appGroup = "group.com.ChatGPT.OPerationsHOS"

    private static func snapshotURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    @MainActor
    static func publish(from store: OperatorStore) {
        let snapshot = Snapshot(
            today:  store.scheduleToday.map { row(from: $0) },
            pinned: store.topLevelPinned.map { row(from: $0) },
            inbox:  store.inbox.map { row(from: $0) }
        )
        guard let url = snapshotURL() else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silent — widget falls back to its empty state if read fails.
        }
    }

    private static func row(from item: OperatorItem) -> Snapshot.Row {
        Snapshot.Row(id: item.id, title: item.title, symbol: item.type.symbol)
    }
}
