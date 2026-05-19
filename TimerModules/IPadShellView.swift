import SwiftUI
import SwiftData

private enum TabKind: Hashable, CaseIterable, Identifiable {
    case dashboard, inbox, schedule, reminders
    case systems, maintenance, projects, people, timers, property
    case vault
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard:   return "Dashboard"
        case .inbox:       return "Inbox"
        case .schedule:    return "Schedule"
        case .reminders:   return "Reminders"
        case .systems:     return "Systems"
        case .maintenance: return "Maintenance"
        case .projects:    return "Projects"
        case .people:      return "People"
        case .timers:      return "Timers"
        case .property:    return "Property"
        case .vault:       return "Vault"
        case .settings:    return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard:   return "rectangle.grid.2x2"
        case .inbox:       return "tray"
        case .schedule:    return "calendar"
        case .reminders:   return "checklist"
        case .systems:     return "house"
        case .maintenance: return "wrench.and.screwdriver"
        case .projects:    return "square.stack.3d.up"
        case .people:      return "person.crop.circle"
        case .timers:      return "timer"
        case .property:    return "building.2"
        case .vault:       return "lock.shield"
        case .settings:    return "gearshape"
        }
    }

    var defaultType: ItemType? {
        switch self {
        case .dashboard, .inbox, .schedule, .settings: return nil
        case .reminders:   return .task
        case .vault:       return .secureNote
        case .systems:     return .homeSystem
        case .maintenance: return .maintenance
        case .projects:    return .project
        case .people:      return .person
        case .timers:      return .timer
        case .property:    return .property
        }
    }
}

struct IPadShellView: View {
    let store: OperatorStore

    @State private var selectedTab: TabKind? = .dashboard
    @State private var selectedRecordID: UUID?
    @State private var middlePath: [UUID] = []
    @State private var newRecordSheet = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            middleColumn
        } detail: {
            detailColumn
        }
        .sheet(isPresented: $newRecordSheet) {
            RecordEditSheet(
                mode: .new,
                store: store,
                defaultType: (selectedTab ?? .dashboard).defaultType
            )
        }
    }

    private var sidebar: some View {
        List(selection: $selectedTab) {
            Section("Meta") {
                rows([.dashboard, .settings, .vault])
            }
            Section("Operations") {
                rows([.inbox, .systems, .maintenance, .projects, .property, .people])
            }
            Section("Time Management") {
                rows([.schedule, .reminders, .timers])
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("OPerationsHOS")
    }

    @ViewBuilder
    private func rows(_ tabs: [TabKind]) -> some View {
        ForEach(tabs) { tab in
            Label(tab.title, systemImage: tab.symbol).tag(tab as TabKind?)
        }
    }

    // Middle column hosts the selected tab's view. NavigationLinks inside
    // those views push UUIDs onto `middlePath`; .onChange intercepts and
    // routes the tapped record to the detail column instead, then empties
    // the path so nothing actually pushes here.
    private var middleColumn: some View {
        NavigationStack(path: $middlePath) {
            tabContent(selectedTab ?? .dashboard)
                .navigationDestination(for: UUID.self) { _ in
                    Color.clear
                }
        }
        .onChange(of: middlePath) { _, newPath in
            if let id = newPath.last {
                selectedRecordID = id
                middlePath = []
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let id = selectedRecordID {
            NavigationStack {
                RecordDetailView(id: id, store: store)
            }
            .id(id)
        } else {
            ContentUnavailableView(
                "No Record Selected",
                systemImage: "doc.text",
                description: Text("Pick a record from the middle pane.")
            )
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: TabKind) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(store: store, showingNewRecord: $newRecordSheet)
        case .inbox:
            InboxView(store: store, showingNewRecord: $newRecordSheet)
        case .schedule:
            ScheduleView(store: store, showingNewRecord: $newRecordSheet)
        case .reminders:
            RemindersView(store: store, showingNewRecord: $newRecordSheet)
        case .systems:
            ModuleView(
                title: "Systems",
                symbol: "house",
                scope: .types([.homeSystem, .appliance]),
                store: store,
                showingNewRecord: $newRecordSheet
            )
        case .maintenance:
            ModuleView(
                title: "Maintenance",
                symbol: "wrench.and.screwdriver",
                scope: .types([.maintenance]),
                store: store,
                showingNewRecord: $newRecordSheet
            )
        case .projects:
            ModuleView(
                title: "Projects",
                symbol: "square.stack.3d.up",
                scope: .types([.project]),
                store: store,
                showingNewRecord: $newRecordSheet
            )
        case .people:
            ModuleView(
                title: "People",
                symbol: "person.crop.circle",
                scope: .types([.person]),
                store: store,
                showingNewRecord: $newRecordSheet
            )
        case .timers:
            ModuleView(
                title: "Timers",
                symbol: "timer",
                scope: .types([.timer]),
                store: store,
                showingNewRecord: $newRecordSheet
            )
        case .property:
            ModuleView(
                title: "Property",
                symbol: "building.2",
                scope: .types([.property]),
                store: store,
                showingNewRecord: $newRecordSheet
            )
        case .vault:
            VaultView(store: store, showingNewRecord: $newRecordSheet)
        case .settings:
            SettingsView(store: store)
        }
    }
}
