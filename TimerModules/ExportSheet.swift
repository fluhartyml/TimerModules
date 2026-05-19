import SwiftUI

struct ExportSheet: View {
    let store: OperatorStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .markdown
    @State private var sharedURL: URL?
    @State private var errorMessage: String?
    @State private var isWorking: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button {
                        runExport()
                    } label: {
                        if isWorking {
                            HStack { ProgressView(); Text("Exporting…") }
                        } else {
                            Label("Export and Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("Exports include all live (non-archived) records. ZIP bundles every format plus attachments.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Export")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sharedURL) { url in
                ShareSheet(url: url)
            }
        }
    }

    private func runExport() {
        errorMessage = nil
        isWorking = true
        Task {
            do {
                let live = store.items.filter { !$0.archived }
                let url = try ExportFormatter.export(items: live, as: selectedFormat)
                await MainActor.run {
                    sharedURL = url
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if canImport(UIKit)
import UIKit

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ShareSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Saved to:")
            Text(url.path).font(.caption.monospaced())
            Button("Reveal in Finder") {
                #if os(macOS)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                #endif
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
