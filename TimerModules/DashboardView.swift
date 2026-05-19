import SwiftUI

struct DashboardView: View {
    let store: OperatorStore
    @Binding var showingNewRecord: Bool
    @State private var searchQuery: String = ""

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [OperatorItem] {
        store.search(searchQuery)
    }

    var body: some View {
        Group {
            if isSearching {
                searchResultsView
            } else if store.items.isEmpty {
                emptyState
            } else {
                populatedDashboard
            }
        }
        .navigationTitle("OPerationsHOS")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search records")
        #else
        .searchable(text: $searchQuery, prompt: "Search records")
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewRecord = true } label: {
                    Label("New Record", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        if searchResults.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text("Nothing matched \u{201C}\(searchQuery)\u{201D}. Vault records are excluded from global search; open Vault to search private content.")
            )
        } else {
            List(searchResults, id: \.id) { item in
                NavigationLink(value: item.id) {
                    OperatorCard(item: item)
                }
                .buttonStyle(.plain)
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }

    private var populatedDashboard: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                section("Today", items: store.today)
                section("Pinned", items: store.topLevelPinned)
                section("Home Systems", items: store.homeSystems)
                section("People", items: store.people)
                section("Projects", items: store.projects)
                section("Upcoming", items: store.upcoming)
                section("Recently Updated", items: store.recentlyUpdated)
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Records Yet", systemImage: "tray")
        } description: {
            Text("Where the moving parts of your life — records, schedules, people, and projects — become retrievable and structured. Tap the plus button to create your first record, or open Settings to grant privacy and security permissions or to populate with sample records.")
        } actions: {
            Button {
                showingNewRecord = true
            } label: {
                Label("New Record", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [OperatorItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.leading, 4)
                ForEach(items) { item in
                    NavigationLink(value: item.id) {
                        OperatorCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            store.togglePin(id: item.id)
                        } label: {
                            Label(item.pinned ? "Unpin" : "Pin",
                                  systemImage: item.pinned ? "pin.slash" : "pin")
                        }
                        Button {
                            store.toggleArchive(id: item.id)
                        } label: {
                            Label(item.archived ? "Unarchive" : "Archive",
                                  systemImage: "archivebox")
                        }
                        Button(role: .destructive) {
                            store.delete(id: item.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
