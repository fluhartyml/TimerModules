import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "rectangle.grid.2x2.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.tint)
                            .frame(width: 60, height: 60)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OPerationsHOS").font(.title2.weight(.semibold))
                            Text("Human Operating System")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Organize. Track. Operate.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Where the moving parts of your life — reminders, events, projects, people, photos, receipts, notes — become retrievable and structured. One Human OPerating System.")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }

            Section("Version") {
                LabeledContent("Build", value: appVersion)
            }

            Section("Links") {
                Link(destination: URL(string: "https://fluharty.me/privacy")!) {
                    Label("Privacy", systemImage: "lock.shield")
                }
                Link(destination: URL(string: "https://github.com/fluhartyml/OPerationsHOS")!) {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://github.com/fluhartyml/OPerationsHOS/wiki")!) {
                    Label("Support / Manual", systemImage: "book")
                }
            }

            Section("Credits") {
                Text("ChatGPT was the architect, engineered by Claude, operated by Michael L. Fluharty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
