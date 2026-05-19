import SwiftUI

struct SearchView: View {
    let store: OperatorStore
    @State private var query: String = ""

    private var results: [OperatorItem] {
        store.search(query)
    }

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Search OPerationsHOS",
                    systemImage: "magnifyingglass",
                    description: Text("Find any record by title, notes, tags, or type.")
                )
            } else if results.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Nothing matched “\(query)”.")
                )
            } else {
                List(results, id: \.id) { item in
                    NavigationLink(value: item.id) {
                        SearchRow(item: item)
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
        }
        .navigationTitle("Search")
        #if os(iOS)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        #else
        .searchable(text: $query)
        #endif
    }
}

private struct SearchRow: View {
    let item: OperatorItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(item.type.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
