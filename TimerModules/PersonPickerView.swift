import SwiftUI
import Contacts

#if os(iOS)
import UIKit
import ContactsUI

@MainActor
final class PickerPresenter: NSObject, CNContactPickerDelegate {
    static let shared = PickerPresenter()
    private var onPick: ((CNContact) -> Void)?

    func present(onPick: @escaping (CNContact) -> Void) {
        self.onPick = onPick

        let picker = CNContactPickerViewController()
        picker.delegate = self

        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow),
              let root = window.rootViewController else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(picker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        onPick?(contact)
        onPick = nil
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onPick = nil
    }
}
#endif

@MainActor
@Observable
final class ContactsAccess {
    enum AuthState { case unknown, authorized, denied, notDetermined }
    var authState: AuthState = .unknown

    private let store = CNContactStore()

    func refreshAuth() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized: authState = .authorized
        case .denied, .restricted: authState = .denied
        case .notDetermined: authState = .notDetermined
        @unknown default:
            // .limited (iOS 18+) and any future cases — treat as authorized
            // since the user has granted some level of access and the picker
            // can still present.
            authState = .authorized
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            authState = granted ? .authorized : .denied
        } catch {
            authState = .denied
        }
    }
}

func lookupContact(identifier: String) -> CNContact? {
    guard !identifier.isEmpty else { return nil }
    let store = CNContactStore()
    let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]
    return try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
}

func displayName(for contact: CNContact) -> String {
    let formatter = CNContactFormatter()
    formatter.style = .fullName
    let formatted = formatter.string(from: contact) ?? ""
    if !formatted.isEmpty { return formatted }
    let combined = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
    return combined.isEmpty ? "Unnamed" : combined
}

#if os(macOS)
struct PersonManualEntrySheet: View {
    let onSave: (String) -> Void
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Person").font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
#endif
