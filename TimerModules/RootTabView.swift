import SwiftUI

/// iPhone (compact size class) tab bar.
/// Four explicit tabs — Dashboard, Inbox, Time (compound), People — chosen for the
/// cognitive-prosthetic frame: aggregate / capture / time / relationships. Everything
/// else (Vault, Systems, Maintenance, Projects, Property, Search, Settings) falls into
/// the iOS auto-generated More overflow. Schedule, Reminders, and Timers no longer
/// appear as standalone tabs — they live inside the Time compound view.
/// Mac and iPad sidebars (MacShellView, IPadShellView) keep all rows visible.
struct RootTabView: View {
    let store: OperatorStore

    @State private var dashboardSheet = false
    @State private var inboxSheet = false
    @State private var peopleSheet = false
    @State private var vaultSheet = false
    @State private var systemsSheet = false
    @State private var maintenanceSheet = false
    @State private var projectsSheet = false
    @State private var propertySheet = false

    var body: some View {
        TabView {
            tab("Dashboard", "rectangle.grid.2x2", sheet: $dashboardSheet, defaultType: nil) {
                DashboardView(store: store, showingNewRecord: $dashboardSheet)
            }

            tab("Inbox", "tray", sheet: $inboxSheet, defaultType: nil) {
                InboxView(store: store, showingNewRecord: $inboxSheet)
            }

            NavigationStack {
                TimeView(store: store)
                    .navigationDestination(for: UUID.self) { id in
                        RecordDetailView(id: id, store: store)
                    }
            }
            .tabItem {
                Label("Time", systemImage: "clock")
            }

            tab("People", "person.2", sheet: $peopleSheet, defaultType: .person) {
                ModuleView(
                    title: "People",
                    symbol: "person.2",
                    scope: .types([.person]),
                    store: store,
                    showingNewRecord: $peopleSheet
                )
            }

            tab("Vault", "lock.shield", sheet: $vaultSheet, defaultType: .secureNote) {
                VaultView(store: store, showingNewRecord: $vaultSheet)
            }

            tab("Systems", "house", sheet: $systemsSheet, defaultType: .homeSystem) {
                ModuleView(
                    title: "Systems",
                    symbol: "house",
                    scope: .types([.homeSystem, .appliance]),
                    store: store,
                    showingNewRecord: $systemsSheet
                )
            }

            tab("Maintenance", "wrench.and.screwdriver", sheet: $maintenanceSheet, defaultType: .maintenance) {
                ModuleView(
                    title: "Maintenance",
                    symbol: "wrench.and.screwdriver",
                    scope: .types([.maintenance]),
                    store: store,
                    showingNewRecord: $maintenanceSheet
                )
            }

            tab("Projects", "square.stack.3d.up", sheet: $projectsSheet, defaultType: .project) {
                ModuleView(
                    title: "Projects",
                    symbol: "square.stack.3d.up",
                    scope: .types([.project]),
                    store: store,
                    showingNewRecord: $projectsSheet
                )
            }

            tab("Property", "building.2", sheet: $propertySheet, defaultType: .property) {
                ModuleView(
                    title: "Property",
                    symbol: "building.2",
                    scope: .types([.property]),
                    store: store,
                    showingNewRecord: $propertySheet
                )
            }

            NavigationStack {
                SettingsView(store: store)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    @ViewBuilder
    private func tab<Content: View>(
        _ title: String,
        _ symbol: String,
        sheet: Binding<Bool>,
        defaultType: ItemType?,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: UUID.self) { id in
                    RecordDetailView(id: id, store: store)
                }
        }
        .tabItem {
            Label(title, systemImage: symbol)
        }
        .sheet(isPresented: sheet) {
            RecordEditSheet(mode: .new, store: store, defaultType: defaultType)
        }
    }
}
