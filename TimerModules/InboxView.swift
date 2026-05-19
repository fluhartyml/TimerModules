import SwiftUI

struct InboxView: View {
    let store: OperatorStore
    @Binding var showingNewRecord: Bool

    var body: some View {
        Group {
            if store.inbox.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle("Inbox")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewRecord = true } label: {
                    Label("New Record", systemImage: "plus")
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                ForEach(store.inbox) { item in
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
            .padding()
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Inbox is empty", systemImage: "tray")
        } description: {
            Text("Records that aren't pinned, dated, or filed into a typed module land here. A staging area for things that haven't been sorted yet.")
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
