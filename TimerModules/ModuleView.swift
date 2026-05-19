import SwiftUI

struct ModuleView: View {
    let title: String
    let symbol: String
    let scope: ModuleScope
    let store: OperatorStore
    @Binding var showingNewRecord: Bool

    @State private var searchText: String = ""
    @State private var selectionMode: Bool = false
    @State private var selectedIDs: Set<UUID> = []

    private var scopedItems: [OperatorItem] {
        let live = store.items.filter { !$0.archived }
        switch scope {
        case .all:
            return live
        case .types(let allowed):
            return live.filter { allowed.contains($0.type) }
        }
    }

    var items: [OperatorItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered: [OperatorItem]
        if trimmed.isEmpty {
            filtered = scopedItems
        } else {
            filtered = scopedItems.filter { matches($0, query: trimmed) }
        }
        return filtered.sorted { $0.updatedDate > $1.updatedDate }
    }

    private func matches(_ item: OperatorItem, query: String) -> Bool {
        if item.title.lowercased().contains(query) { return true }
        if item.subtitle.lowercased().contains(query) { return true }
        if item.body.lowercased().contains(query) { return true }
        if item.type.label.lowercased().contains(query) { return true }
        if item.status.label.lowercased().contains(query) { return true }
        if let system = item.relatedSystem, system.lowercased().contains(query) { return true }
        if item.tags.contains(where: { $0.lowercased().contains(query) }) { return true }
        return false
    }

    var body: some View {
        Group {
            if items.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(text: $searchText, prompt: "Search \(title)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewRecord = true } label: {
                    Label("New Record", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    selectionMode.toggle()
                    if !selectionMode { selectedIDs.removeAll() }
                } label: {
                    Label(selectionMode ? "Done" : "Select",
                          systemImage: selectionMode ? "xmark.circle" : "checklist")
                }
            }
            if selectionMode && !selectedIDs.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button {
                            selectedIDs.forEach { store.togglePin(id: $0) }
                            selectedIDs.removeAll()
                        } label: {
                            Label("Pin / Unpin", systemImage: "pin")
                        }
                        Button {
                            selectedIDs.forEach { store.toggleArchive(id: $0) }
                            selectedIDs.removeAll()
                        } label: {
                            Label("Archive / Unarchive", systemImage: "archivebox")
                        }
                        Button(role: .destructive) {
                            selectedIDs.forEach { store.delete(id: $0) }
                            selectedIDs.removeAll()
                            selectionMode = false
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Label("\(selectedIDs.count) Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                ForEach(items) { item in
                    if selectionMode {
                        Button {
                            if selectedIDs.contains(item.id) {
                                selectedIDs.remove(item.id)
                            } else {
                                selectedIDs.insert(item.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(item.id) ? Color.accentColor : Color.secondary)
                                OperatorCard(item: item)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
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
            .padding()
        }
    }

    private var empty: some View {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        return Group {
            if !trimmedQuery.isEmpty {
                ContentUnavailableView.search(text: trimmedQuery)
            } else {
                ContentUnavailableView {
                    Label("Nothing in \(title) yet", systemImage: symbol)
                } description: {
                    Text(emptyMessage)
                } actions: {
                    Button {
                        showingNewRecord = true
                    } label: {
                        Label("New Record", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var emptyMessage: String {
        switch scope {
        case .all:
            return "Every record you create lands here. Tap the plus button to start."
        case .types:
            return "Records you mark as \(title.lowercased()) appear here."
        }
    }
}

enum ModuleScope: Equatable {
    case all
    case types(Set<ItemType>)
}
