import SwiftUI

/// iPhone tab-bar compound that reveals the three Time-Management sub-modules
/// (Schedule, Reminders, Timers) behind a single tab slot. On Mac and iPad each
/// of those views has its own sidebar row inside the Time Management section;
/// iPhone collapses them here to free a slot for People in the four-tab bar.
struct TimeView: View {
    let store: OperatorStore

    @State private var scheduleSheet = false
    @State private var remindersSheet = false
    @State private var timersSheet = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ScheduleView(store: store, showingNewRecord: $scheduleSheet)
                } label: {
                    row(label: "Schedule", symbol: "calendar")
                }
                NavigationLink {
                    RemindersView(store: store, showingNewRecord: $remindersSheet)
                } label: {
                    row(label: "Reminders", symbol: "checklist")
                }
                NavigationLink {
                    ModuleView(
                        title: "Timers",
                        symbol: "timer",
                        scope: .types([.timer]),
                        store: store,
                        showingNewRecord: $timersSheet
                    )
                } label: {
                    row(label: "Timers", symbol: "timer")
                }
            } header: {
                Text("Time Management")
            } footer: {
                Text("Schedule for date-anchored events, Reminders for tasks, Timers for elapsed-time tracking.")
            }
        }
        .navigationTitle("Time")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $scheduleSheet) {
            RecordEditSheet(mode: .new, store: store, defaultType: nil)
        }
        .sheet(isPresented: $remindersSheet) {
            RecordEditSheet(mode: .new, store: store, defaultType: .task)
        }
        .sheet(isPresented: $timersSheet) {
            RecordEditSheet(mode: .new, store: store, defaultType: .timer)
        }
    }

    private func row(label: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(label)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}
