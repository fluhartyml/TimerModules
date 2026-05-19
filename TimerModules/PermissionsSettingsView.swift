import SwiftUI
import AVFoundation
import EventKit
import Contacts

/// Inline list of iOS permissions OPerationsHOS uses, with a Grant button per
/// permission that pre-fires the system prompt before the user encounters the
/// just-in-time flow. Status updates after each request. Pattern matches Apple's
/// own Privacy & Security section (denied → user must visit Settings.app).
/// Granting Contacts auto-imports the selected/all contacts into People CRM
/// as Person records.
struct PermissionsSettingsView: View {
    let store: OperatorStore?

    init(store: OperatorStore? = nil) {
        self.store = store
    }

    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var remindersStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @State private var calendarStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var contactsStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var lastContactImportCount: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    /// Re-fetches every iOS permission status. Runs on view appear and on
    /// scenePhase return-to-active so the UI reflects external changes (user
    /// revokes a permission in Settings.app, or the system-level prompt's
    /// completion callback races the view's state assignment).
    private func refreshAllStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    var body: some View {
        Section {
            permissionRow(
                title: "Camera",
                symbol: "camera",
                statusText: cameraStatusText,
                granted: cameraStatus == .authorized,
                denied: cameraStatus == .denied || cameraStatus == .restricted
            ) {
                requestCameraAccess()
            }

            permissionRow(
                title: "Reminders",
                symbol: "checklist",
                statusText: ekStatusText(remindersStatus),
                granted: isGrantedReminders(remindersStatus),
                denied: remindersStatus == .denied || remindersStatus == .restricted
            ) {
                requestRemindersAccess()
            }

            permissionRow(
                title: "Calendar",
                symbol: "calendar",
                statusText: ekStatusText(calendarStatus),
                granted: isGrantedCalendar(calendarStatus),
                denied: calendarStatus == .denied || calendarStatus == .restricted
            ) {
                requestCalendarAccess()
            }

            permissionRow(
                title: "Contacts",
                symbol: "person.crop.circle",
                statusText: contactsStatusText,
                granted: isContactsGranted(contactsStatus),
                denied: contactsStatus == .denied || contactsStatus == .restricted
            ) {
                requestContactsAccess()
            }

            if lastContactImportCount > 0 {
                Label(
                    "Imported \(lastContactImportCount) contact\(lastContactImportCount == 1 ? "" : "s") into People",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        } header: {
            Text("Privacy & Security Permissions")
        } footer: {
            Text("Grant in advance so the camera scanner, EventKit sync, and Contacts integration work without interruption later. Granting Contacts also imports the contacts you allow as Person records in People CRM. Denied permissions can be changed from Settings \u{203A} OPerationsHOS in the iOS Settings app.")
        }
        .onAppear { refreshAllStatuses() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refreshAllStatuses() }
        }
    }

    /// Row layout puts the status text BELOW the label so neither one fights for
    /// horizontal room. Avoids the multi-line word-wrap on narrower screens.
    @ViewBuilder
    private func permissionRow(
        title: String,
        symbol: String,
        statusText: String,
        granted: Bool,
        denied: Bool,
        request: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(granted ? Color.green : (denied ? Color.red : Color.secondary))
            }
            Spacer()
            if !granted && !denied {
                Button("Grant") { request() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Camera

    private var cameraStatusText: String {
        switch cameraStatus {
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async {
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    // MARK: - EventKit (Reminders / Calendar)

    private func ekStatusText(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorized: return "Granted"
        case .fullAccess: return "Granted"
        case .writeOnly: return "Write only"
        @unknown default: return "Unknown"
        }
    }

    private func isGrantedReminders(_ status: EKAuthorizationStatus) -> Bool {
        status == .fullAccess || status == .authorized
    }

    private func isGrantedCalendar(_ status: EKAuthorizationStatus) -> Bool {
        status == .fullAccess || status == .authorized
    }

    private func requestRemindersAccess() {
        if #available(iOS 17.0, macOS 14.0, *) {
            Task { @MainActor in
                _ = try? await eventStore.requestFullAccessToReminders()
                remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
            }
        } else {
            eventStore.requestAccess(to: .reminder) { _, _ in
                DispatchQueue.main.async {
                    remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
                }
            }
        }
    }

    private func requestCalendarAccess() {
        if #available(iOS 17.0, macOS 14.0, *) {
            Task { @MainActor in
                _ = try? await eventStore.requestFullAccessToEvents()
                calendarStatus = EKEventStore.authorizationStatus(for: .event)
            }
        } else {
            eventStore.requestAccess(to: .event) { _, _ in
                DispatchQueue.main.async {
                    calendarStatus = EKEventStore.authorizationStatus(for: .event)
                }
            }
        }
    }

    // MARK: - Contacts

    private var contactsStatusText: String {
        switch contactsStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorized: return "Granted"
        #if os(iOS)
        case .limited: return "Limited"
        #endif
        @unknown default: return "Unknown"
        }
    }

    private func isContactsGranted(_ status: CNAuthorizationStatus) -> Bool {
        if status == .authorized { return true }
        #if os(iOS)
        if status == .limited { return true }
        #endif
        return false
    }

    private func requestContactsAccess() {
        contactStore.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
                if granted, let store {
                    importAllAccessibleContacts(into: store)
                }
            }
        }
    }

    /// After Contacts access is granted (Full or Limited), fetch every contact
    /// the app can see and create matching Person records in People CRM. Uses
    /// the contact's stable identifier as `OperatorItem.source` so re-runs
    /// don't double-create. Existing Person records with the same source are
    /// left alone.
    @MainActor
    private func importAllAccessibleContacts(into store: OperatorStore) {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let existingSources = Set(store.items.compactMap { $0.source })

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        var imported = 0
        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                guard !existingSources.contains(contact.identifier) else { return }
                let name = displayName(for: contact)
                guard !name.isEmpty else { return }
                let subtitle = contact.organizationName.isEmpty ? "" : contact.organizationName
                let person = OperatorItem(
                    title: name,
                    subtitle: subtitle,
                    body: "",
                    type: .person,
                    status: .open,
                    priority: .normal,
                    createdDate: Date(),
                    updatedDate: Date(),
                    dueDate: nil,
                    pinned: false,
                    archived: false,
                    isSecure: false,
                    tags: [],
                    relatedSystem: nil,
                    source: contact.identifier
                )
                store.add(person)
                imported += 1
            }
        } catch {
            // Silent — contacts import will retry next time the user opens this section
            // or grants access again. lastContactImportCount stays at 0.
        }
        lastContactImportCount = imported
    }

    private func displayName(for contact: CNContact) -> String {
        let given = contact.givenName.trimmingCharacters(in: .whitespaces)
        let family = contact.familyName.trimmingCharacters(in: .whitespaces)
        let joined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        if !joined.isEmpty { return joined }
        if !contact.organizationName.isEmpty { return contact.organizationName }
        return ""
    }
}
