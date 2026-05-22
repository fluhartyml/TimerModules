// MARK: - CPMEventEditorView
//
// Sheet presented from CPMDetailView's Face 2 (Event grid) when the
// user taps a row or the toolbar + button. Hosts the four locked
// recurrence-rule modes from the spec:
//   • oneOff — a single specific date
//   • ordinalWeekday — Nth weekday of month
//   • lastDayOfMonth — variable 28/29/30/31
//   • everyNMonths — every N months on a chosen weekday
//
// Phase 4 ships the .oneOff editor fully. The other three modes are
// selectable but their per-mode parameter editors ship as "coming soon"
// stubs — the data shape (recurrenceParamsJSON) accepts them. Per-mode
// editors are filled in during Phase 5/6 when recurrence resolution lands.

import SwiftUI
import SwiftData

struct CPMEventEditorView: View {
    @Bindable var event: CPMEvent

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Selected recurrence mode (mirrors event.recurrenceModeRaw).
    @State private var selectedMode: CPMEventRecurrenceMode = .oneOff

    /// One-off date picker state (Phase 4's only fully-wired mode).
    @State private var oneOffDate: Date = Date()

    /// Comma-separated port numbers as edited by the user. Validated
    /// + normalized on Save into event.portNumbers (1...52, deduped, sorted).
    @State private var portsText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Name", text: $event.eventName)
                    TextField(
                        "Brief description (max 22 chars)",
                        text: Binding(
                            get: { event.briefDescription },
                            set: { event.briefDescription = String($0.prefix(22)) }
                        )
                    )
                }

                Section("Output ports (1-52)") {
                    TextField("e.g. 7, 12, 23", text: $portsText)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled(true)
                    Text("Comma-separated port numbers. Each event can fire one or many ports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("When") {
                    Picker("Recurrence", selection: $selectedMode) {
                        ForEach(CPMEventRecurrenceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    switch selectedMode {
                    case .oneOff:
                        DatePicker(
                            "Fire on",
                            selection: $oneOffDate,
                            displayedComponents: [.date]
                        )
                    case .ordinalWeekday, .lastDayOfMonth, .everyNMonths:
                        Text("Per-mode editor for \"\(selectedMode.displayName)\" ships in a later iteration. Mode is recorded but parameters can't be set yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Behavior") {
                    Toggle("Notify when firing", isOn: $event.notifyEnabled)
                    Toggle("Protected window (suppresses other events)", isOn: $event.isProtected)
                }
            }
            .navigationTitle(event.eventName.isEmpty ? "New event" : event.eventName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // If this is a fresh "add" with no real edits, remove
                        // the placeholder row so we don't leave a blank in the
                        // list. Heuristic: empty name AND empty ports.
                        if event.eventName.isEmpty && event.portNumbers.isEmpty {
                            modelContext.delete(event)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(event.eventName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                selectedMode = CPMEventRecurrenceMode(rawValue: event.recurrenceModeRaw) ?? .oneOff
                portsText = event.portNumbers.sorted().map(String.init).joined(separator: ", ")
                oneOffDate = decodedOneOffDate() ?? Date()
            }
        }
    }

    /// Decode a stored .oneOff date from the recurrenceParamsJSON blob.
    private func decodedOneOffDate() -> Date? {
        guard let data = event.recurrenceParamsJSON.data(using: .utf8) else { return nil }
        struct OneOffParams: Codable { let date: Date }
        return try? JSONDecoder().decode(OneOffParams.self, from: data).date
    }

    /// Encode the current .oneOff date back into recurrenceParamsJSON.
    private func encodedOneOffJSON() -> String {
        struct OneOffParams: Codable { let date: Date }
        let blob = OneOffParams(date: oneOffDate)
        if let data = try? JSONEncoder().encode(blob),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private func saveAndDismiss() {
        // Mode
        event.recurrenceModeRaw = selectedMode.rawValue
        if selectedMode == .oneOff {
            event.recurrenceParamsJSON = encodedOneOffJSON()
        }
        // Ports — parse, validate, dedup, sort
        let candidates = portsText
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...CPMBrickData.portCount).contains($0) }
        event.portNumbers = Array(Set(candidates)).sorted()
        // Bookkeeping
        event.updatedDate = Date()
        dismiss()
    }
}
