import SwiftUI
import Contacts

struct RecordEditSheet: View {
    enum Mode {
        case new
        case edit(UUID)
    }

    let mode: Mode
    let store: OperatorStore
    let defaultType: ItemType?

    @State private var title: String = ""
    @State private var type: ItemType = .note
    @State private var status: ItemStatus = .open
    @State private var priority: ItemPriority = .normal
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var bodyText: String = ""
    @State private var tagsText: String = ""
    @State private var pinned: Bool = false
    @State private var contactIdentifier: String = ""

    @State private var contactsAccess = ContactsAccess()

    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, store: OperatorStore, defaultType: ItemType? = nil) {
        self.mode = mode
        self.store = store
        self.defaultType = defaultType
        if let defaultType {
            _type = State(initialValue: defaultType)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    if type == .person {
                        Button {
                            requestContactsAndPresent()
                        } label: {
                            Label(contactIdentifier.isEmpty ? "Pick from Contacts" : "Change Contact",
                                  systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                }

                Section {
                    Picker("Type", selection: $type) {
                        ForEach(ItemType.allCases) { t in
                            Label(t.label, systemImage: t.symbol).tag(t)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ItemStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(ItemPriority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    Toggle("Pinned", isOn: $pinned)
                }

                Section {
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $bodyText, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Tags") {
                    TextField("Comma-separated", text: $tagsText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(navTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadIfEditing()
                contactsAccess.refreshAuth()
            }
        }
    }

    private var navTitle: String {
        switch mode {
        case .new: return "New Record"
        case .edit: return "Edit Record"
        }
    }

    private func loadIfEditing() {
        if case let .edit(id) = mode, let existing = store.item(id: id) {
            title = existing.title
            type = existing.type
            status = existing.status
            priority = existing.priority
            hasDueDate = existing.dueDate != nil
            dueDate = existing.dueDate ?? Date()
            bodyText = existing.body
            tagsText = existing.tags.joined(separator: ", ")
            pinned = existing.pinned
            contactIdentifier = existing.source ?? ""
        }
    }

    private func requestContactsAndPresent() {
        #if os(iOS)
        Task {
            if contactsAccess.authState != .authorized {
                await contactsAccess.requestAccess()
            }
            guard contactsAccess.authState == .authorized else { return }
            PickerPresenter.shared.present { contact in
                title = displayName(for: contact)
                contactIdentifier = contact.identifier
            }
        }
        #endif
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let parsedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let storedSource: String? = contactIdentifier.isEmpty ? nil : contactIdentifier

        switch mode {
        case .new:
            let newItem = OperatorItem(
                title: trimmedTitle,
                body: bodyText,
                type: type,
                status: status,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil,
                pinned: pinned,
                tags: parsedTags,
                source: storedSource
            )
            store.add(newItem)

        case .edit(let id):
            guard var existing = store.item(id: id) else { return }
            existing.title = trimmedTitle
            existing.body = bodyText
            existing.type = type
            existing.status = status
            existing.priority = priority
            existing.dueDate = hasDueDate ? dueDate : nil
            existing.pinned = pinned
            existing.tags = parsedTags
            existing.source = storedSource
            store.update(existing)
        }
        dismiss()
    }
}
