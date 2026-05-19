import SwiftUI

/// Modal for adding a new access grant to a record. Owner picks one Person
/// from People CRM and the permission level (read vs read+write). Phase 2
/// will wire this into the iOS share sheet for actual iMessage / email
/// delivery; Phase 1 manages the in-app ACL only.
struct ShareAccessSheet: View {
    let record: OperatorItem
    let store: OperatorStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPersonID: UUID?
    @State private var permission: AccessPermission = .read

    private var availablePeople: [OperatorItem] {
        let alreadyShared = Set(record.accessGrants.map { $0.personID })
        return store.items
            .filter { $0.type == .person && !$0.archived }
            .filter { !alreadyShared.contains($0.id) }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        NavigationStack {
            Form {
                if availablePeople.isEmpty {
                    Section {
                        Text("No people available to share with. Add a Person to People CRM, or this record already has every Person flagged as a recipient.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Recipient") {
                        Picker("Person", selection: $selectedPersonID) {
                            Text("Choose a person").tag(UUID?.none)
                            ForEach(availablePeople) { person in
                                Text(person.title).tag(Optional(person.id))
                            }
                        }
                    }

                    Section("Permission") {
                        Picker("Level", selection: $permission) {
                            ForEach(AccessPermission.allCases) { level in
                                Label(level.label, systemImage: level.symbol).tag(level)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        Text(permission.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Share Access")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Grant") {
                        if let id = selectedPersonID {
                            store.grantAccess(to: record.id, person: id, permission: permission)
                            dismiss()
                        }
                    }
                    .disabled(selectedPersonID == nil)
                }
            }
        }
    }
}
