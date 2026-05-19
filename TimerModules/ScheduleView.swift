import SwiftUI

enum ScheduleScope: String, CaseIterable, Identifiable {
    case operationsHOS = "OPerationsHOS"
    case allCalendars = "All Calendars"
    var id: String { rawValue }
}

struct ScheduleView: View {
    let store: OperatorStore
    @Binding var showingNewRecord: Bool

    @State private var scope: ScheduleScope = .operationsHOS

    var body: some View {
        VStack(spacing: 0) {
            Picker("Scope", selection: $scope) {
                ForEach(ScheduleScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch scope {
                case .operationsHOS:
                    operationsList
                case .allCalendars:
                    allCalendarsPlaceholder
                }
            }
        }
        .navigationTitle("Schedule")
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

    // MARK: - OPerationsHOS list (agenda style)

    private var datedItems: [OperatorItem] {
        store.items
            .filter { !$0.archived && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var groupedByDay: [(day: Date, items: [OperatorItem])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let groups = Dictionary(grouping: datedItems) { item in
            cal.startOfDay(for: item.dueDate ?? Date())
        }
        let sortedDays = groups.keys.sorted()
        // Today + future ascending (today topmost), then past descending (most recent past first).
        let todayAndFuture = sortedDays.filter { $0 >= today }
        let past = Array(sortedDays.filter { $0 < today }.reversed())
        return (todayAndFuture + past).map { day in
            (day, groups[day] ?? [])
        }
    }

    @ViewBuilder
    private var operationsList: some View {
        if datedItems.isEmpty {
            emptyOperations
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedByDay, id: \.day) { group in
                        Section {
                            VStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                                ForEach(group.items) { item in
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
                            .padding(.horizontal)
                        } header: {
                            dayHeader(group.day)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let isPast = day < cal.startOfDay(for: Date())

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isToday ? Color.accentColor : (isPast ? Color.secondary : Color.primary))
                .frame(width: 44, alignment: .leading)
            Text(day.formatted(.dateTime.month(.abbreviated).day()))
                .font(.subheadline)
                .foregroundStyle(isToday ? Color.accentColor : (isPast ? Color.secondary : Color.primary))
            if isToday {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.background.opacity(0.94))
    }

    private var emptyOperations: some View {
        ContentUnavailableView {
            Label("Nothing scheduled", systemImage: "calendar")
        } description: {
            Text("Records with a due date appear here, grouped by day. Tap the plus button to add one.")
        } actions: {
            Button {
                showingNewRecord = true
            } label: {
                Label("New Record", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - All Calendars (Phase 20 wiring)

    private var allCalendarsPlaceholder: some View {
        ContentUnavailableView {
            Label("All Calendars", systemImage: "calendar.badge.clock")
        } description: {
            Text("Read-only view of every calendar you've granted access to. Wires up when EventKit two-way sync ships in Phase 20.")
        }
    }
}
