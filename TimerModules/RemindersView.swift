import SwiftUI
import EventKit

struct RemindersView: View {
    let store: OperatorStore
    @Binding var showingNewRecord: Bool

    @Bindable private var ek = EventKitStore.shared
    @State private var reminders: [EKReminder] = []
    @State private var loading: Bool = false

    var body: some View {
        Group {
            if !ek.remindersAuthorized {
                authPrompt
            } else if loading && reminders.isEmpty {
                ProgressView("Loading reminders…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reminders.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle("Reminders")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewRecord = true } label: {
                    Label("New Reminder", systemImage: "plus")
                }
            }
        }
        .task {
            await loadIfNeeded()
        }
        .refreshable {
            await refreshReminders()
        }
    }

    private func loadIfNeeded() async {
        if !ek.remindersAuthorized {
            _ = await ek.requestRemindersAccess()
        }
        await refreshReminders()
    }

    private func refreshReminders() async {
        guard ek.remindersAuthorized else { return }
        loading = true
        let pulled = await ek.remindersInDedicatedList()
        reminders = pulled.sorted { lhs, rhs in
            switch (lhs.isCompleted, rhs.isCompleted) {
            case (false, true): return true
            case (true, false): return false
            default:
                let l = lhs.dueDateComponents.flatMap { Calendar.current.date(from: $0) } ?? .distantFuture
                let r = rhs.dueDateComponents.flatMap { Calendar.current.date(from: $0) } ?? .distantFuture
                return l < r
            }
        }
        loading = false
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                    reminderRow(reminder)
                }
            }
            .padding()
        }
    }

    private func reminderRow(_ reminder: EKReminder) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                toggleComplete(reminder)
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(reminder.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title ?? "Untitled")
                    .font(.body)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let due = reminder.dueDateComponents,
                   let date = Calendar.current.date(from: due) {
                    Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func toggleComplete(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        if reminder.isCompleted {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }
        let store = EKEventStore()
        try? store.save(reminder, commit: true)
        Task { await refreshReminders() }
    }

    private var authPrompt: some View {
        ContentUnavailableView {
            Label("Reminders Access Needed", systemImage: "checklist")
        } description: {
            Text("OPerationsHOS keeps a dedicated reminders list called 'OPerationsHOS' in sync. Grant access to use this tab.")
        } actions: {
            Button {
                Task {
                    _ = await ek.requestRemindersAccess()
                    await refreshReminders()
                }
            } label: {
                Label("Grant Access", systemImage: "lock.open")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No reminders yet", systemImage: "checklist")
        } description: {
            Text("Reminders you create from OPerationsHOS or Reminders.app's 'OPerationsHOS' list show up here.")
        } actions: {
            Button {
                showingNewRecord = true
            } label: {
                Label("New Reminder", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
