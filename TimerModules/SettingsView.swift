import SwiftUI

struct SettingsView: View {
    let store: OperatorStore?

    @State private var apiKey: String = ""
    @State private var savedConfirmation: Bool = false
    @State private var showingExport: Bool = false
    @State private var showingPopulateResult: Bool = false
    @State private var populateResultText: String = ""

    init(store: OperatorStore? = nil) {
        self.store = store
    }

    var body: some View {
        Form {
            if let store {
                Section {
                    Button {
                        let result = store.populateSampleRecords()
                        if result.inserted == 0 && result.refreshed > 0 {
                            populateResultText = "Refreshed dates on \(result.refreshed) existing sample\(result.refreshed == 1 ? "" : "s"). No new records added."
                        } else if result.inserted > 0 && result.refreshed == 0 {
                            populateResultText = "Added \(result.inserted) new sample record\(result.inserted == 1 ? "" : "s")."
                        } else {
                            populateResultText = "Added \(result.inserted) new record\(result.inserted == 1 ? "" : "s"), refreshed dates on \(result.refreshed) existing."
                        }
                        showingPopulateResult = true
                    } label: {
                        Label("Populate sample records", systemImage: "tray.and.arrow.down")
                    }
                } header: {
                    Text("Sample Records")
                } footer: {
                    Text("Adds fifteen example records covering the main item types plus two preset focus timers (Focus Cycle 25/5 and Long Focus Session). Tapping again refreshes the sample dates to today's anchor and restores any you've deleted; existing record content stays put. To clear everything, delete and reinstall the app.")
                }
                .alert("Sample Records", isPresented: $showingPopulateResult) {
                    Button("OK") { }
                } message: {
                    Text(populateResultText)
                }

                Section {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export records", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Export")
                } footer: {
                    Text("Save your records as Markdown, CSV, JSON, PDF, or a complete ZIP bundle.")
                }
                .sheet(isPresented: $showingExport) {
                    ExportSheet(store: store)
                }
            }
            Section {
                SecureField("Anthropic API Key", text: $apiKey)
                    .autocorrectionDisabled()
                HStack {
                    Button("Save") {
                        save()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    Spacer()
                    if KeychainStorage.read(.anthropicAPIKey) != nil {
                        Button(role: .destructive) {
                            clear()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                if savedConfirmation {
                    Label("Saved to Keychain", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            } header: {
                Text("Anthropic API")
            } footer: {
                Text("AI actions (Summarize, Extract Dates, Suggest Category) call the Anthropic API directly using your key. Keys are stored in the iOS Keychain and never leave the device except as the Authorization header on requests to api.anthropic.com.")
            }

            PermissionsSettingsView(store: store)

            Section("About") {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About OPerationsHOS", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            apiKey = KeychainStorage.read(.anthropicAPIKey) ?? ""
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        KeychainStorage.write(.anthropicAPIKey, value: trimmed)
        savedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            savedConfirmation = false
        }
    }

    private func clear() {
        KeychainStorage.delete(.anthropicAPIKey)
        apiKey = ""
        savedConfirmation = false
    }
}
