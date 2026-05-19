import SwiftUI

/// Modal sheet for logging a CRM interaction against a Person record.
/// User picks the interaction type (Call / Message / Email / Meeting / Note),
/// optionally adds a free-form summary, taps Save. The entry lands in the
/// person record's activity log as an `ActivityEvent` with `isInteraction == true`.
struct LogInteractionSheet: View {
    let person: OperatorItem
    let store: OperatorStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: ActivityKind = .interactionCall
    @State private var summary: String = ""

    private static let kinds: [ActivityKind] = [
        .interactionCall,
        .interactionMessage,
        .interactionEmail,
        .interactionMeeting,
        .interactionNote
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Interaction Type") {
                    Picker("Type", selection: $selectedKind) {
                        ForEach(Self.kinds, id: \.self) { kind in
                            Label(kind.label, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Summary") {
                    TextField("Brief note about this interaction (optional)",
                              text: $summary,
                              axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Text("Logged interactions appear in this person's activity log with a timestamp. Use this to build a chronological history of your relationship with them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Interaction with \(person.title)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.logInteraction(kind: selectedKind, on: person, summary: summary)
                        dismiss()
                    }
                }
            }
        }
    }
}
