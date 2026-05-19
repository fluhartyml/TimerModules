import SwiftUI
import LocalAuthentication

struct VaultView: View {
    let store: OperatorStore
    @Binding var showingNewRecord: Bool

    @State private var unlocked: Bool = false
    @State private var authError: String?
    @State private var authenticating: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !unlocked {
                lockedGate
            } else {
                disclosureList
            }
        }
        .navigationTitle("Vault")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            if unlocked {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        unlocked = false
                    } label: {
                        Label("Lock", systemImage: "lock.fill")
                    }
                }
            }
        }
        .onAppear {
            // Auto-trigger biometric on tab appearance if still locked.
            if !unlocked && !authenticating {
                authenticate()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Sentry challenges entry, not stay. Vault relocks only when the scene
            // backgrounds (app switcher, home swipe, device auto-lock / screen blank).
            // While Vault is open and the app is foregrounded, no further challenges.
            if newPhase == .background || newPhase == .inactive {
                unlocked = false
            }
        }
    }

    // MARK: - Locked gate

    private var lockedGate: some View {
        ContentUnavailableView {
            Label("Vault Locked", systemImage: "lock.shield.fill")
        } description: {
            Text("Use Face ID or Touch ID to unlock the Vault. Contains private media, transcriptions, secure notes, and secure records.")
            if let authError {
                Text(authError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } actions: {
            Button {
                authenticate()
            } label: {
                if authenticating {
                    HStack { ProgressView(); Text("Authenticating…") }
                } else {
                    Label("Unlock", systemImage: "faceid")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authenticating)
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedReason = "Unlock the Vault"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authError = error?.localizedDescription ?? "Biometric authentication unavailable on this device."
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock the Vault") { success, evalError in
            DispatchQueue.main.async {
                authenticating = false
                if success {
                    unlocked = true
                    authError = nil
                } else {
                    authError = evalError?.localizedDescription ?? "Authentication failed."
                }
            }
        }
    }

    // MARK: - Three-row disclosure (Media / Transcription / Secure Notes)

    private func count(of type: ItemType) -> Int {
        store.items.filter { !$0.archived && $0.type == type }.count
    }

    private var disclosureList: some View {
        List {
            Section {
                NavigationLink {
                    VaultSubsectionView(store: store, type: .media, showingNewRecord: $showingNewRecord)
                } label: {
                    disclosureRow(label: "Media", symbol: "photo", count: count(of: .media))
                }
                NavigationLink {
                    VaultSubsectionView(store: store, type: .transcription, showingNewRecord: $showingNewRecord)
                } label: {
                    disclosureRow(label: "Transcription", symbol: "waveform", count: count(of: .transcription))
                }
                NavigationLink {
                    VaultSubsectionView(store: store, type: .secureNote, showingNewRecord: $showingNewRecord)
                } label: {
                    disclosureRow(label: "Secure Notes", symbol: "lock.doc", count: count(of: .secureNote))
                }
                NavigationLink {
                    VaultSecureRecordsView(store: store)
                } label: {
                    disclosureRow(label: "Secure Records", symbol: "lock.shield", count: store.secureRecords.count)
                }
            } header: {
                Text("Private")
            } footer: {
                Text("Records here stay behind biometric authentication. Tap a section to drill in.")
            }
        }
    }

    private func disclosureRow(label: String, symbol: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(label)
                .font(.body)
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sub-section view (filtered by single vault-only type)

struct VaultSubsectionView: View {
    let store: OperatorStore
    let type: ItemType
    @Binding var showingNewRecord: Bool

    private var items: [OperatorItem] {
        store.items
            .filter { !$0.archived && $0.type == type }
            .sorted { $0.updatedDate > $1.updatedDate }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle(type.label)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewRecord = true } label: {
                    Label("New \(type.label)", systemImage: "plus")
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                ForEach(items) { item in
                    row(for: item)
                }
            }
            .padding()
        }
    }

    /// Media-typed records inside Vault > Media route to MediaDetailView
    /// (image-first), not the universal RecordDetailView. Everything else
    /// uses the value-based UUID routing that surfaces RecordDetailView.
    @ViewBuilder
    private func row(for item: OperatorItem) -> some View {
        if type == .media {
            NavigationLink {
                MediaDetailView(id: item.id, store: store)
            } label: {
                OperatorCard(item: item)
            }
            .buttonStyle(.plain)
            .contextMenu { rowContextMenu(for: item) }
        } else {
            NavigationLink(value: item.id) {
                OperatorCard(item: item)
            }
            .buttonStyle(.plain)
            .contextMenu { rowContextMenu(for: item) }
        }
    }

    @ViewBuilder
    private func rowContextMenu(for item: OperatorItem) -> some View {
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

    private var empty: some View {
        ContentUnavailableView {
            Label("No \(type.label.lowercased()) yet", systemImage: type.symbol)
        } description: {
            Text(emptyMessage)
        } actions: {
            Button {
                showingNewRecord = true
            } label: {
                Label("New \(type.label)", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyMessage: String {
        switch type {
        case .media: return "Photos, videos, and other media you want kept private. Tap the plus button to add the first one."
        case .transcription: return "Voice memos transcribed and kept inside the Vault. Tap the plus button to record."
        case .secureNote: return "Notes that should stay behind biometric authentication. Tap the plus button to add one."
        default: return "Records of this type appear here."
        }
    }
}

// MARK: - Secure Records sub-section (filter: isSecure == true, regardless of type)

struct VaultSecureRecordsView: View {
    let store: OperatorStore
    @State private var secureToast: ToastInfo?

    private var items: [OperatorItem] {
        store.secureRecords
    }

    var body: some View {
        Group {
            if items.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle("Secure Records")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toast($secureToast)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.cardSpacing) {
                ForEach(items) { item in
                    NavigationLink(value: item.id) {
                        OperatorCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            let id = item.id
                            store.toggleSecure(id: id)
                            secureToast = ToastInfo(
                                message: "Removed from Vault",
                                undoAction: { store.toggleSecure(id: id) }
                            )
                        } label: {
                            Label("Remove from Vault", systemImage: "lock.shield")
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
            .padding()
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No secure records yet", systemImage: "lock.shield")
        } description: {
            Text("Records you flag as secure from any module land here. Open any record's detail view and tap the vault icon to move it in.")
        }
    }
}
