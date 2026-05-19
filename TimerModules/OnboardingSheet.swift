import SwiftUI

/// One-time welcome sheet shown on the first launch after install. After the user
/// completes either path (Populate Samples / Start Fresh), the `hasShownWelcome`
/// flag is set in UserDefaults so this never re-fires. Permissions stay
/// just-in-time per iOS convention — no permission gauntlet here.
///
/// Future-work note (Michael 2026-05-15): a proper interactive "Take a Tour"
/// experience should ship as a separate feature. Animated callouts per gesture
/// (tab bar → Dashboard → Pin/Vault toggles → Vault sentry challenge → Share
/// action → record detail flow), with temporary sample records seeded at tour
/// start and auto-removed at tour completion. User records created during the
/// tour stay. The current "Populate Samples" button is sample-data only — not
/// a real tour. Replacing the button label with the honest description until
/// the proper tour ships.
struct OnboardingSheet: View {
    let onTour: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tint)
                Text("Welcome to OPerationsHOS")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Where the moving parts of your life — records, schedules, people, and projects — become retrievable and structured.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onTour()
                } label: {
                    Text("Populate Samples")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Adds a small set of sample records — appliances, people, projects, and a couple of preset timers — so the modules are populated to explore. Easy to delete or replace later from Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    onStart()
                } label: {
                    Text("Start Fresh")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: 480)
    }
}
