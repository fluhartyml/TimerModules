import SwiftUI
import SwiftData

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppShellInner(modelContext: modelContext)
    }
}

private struct AppShellInner: View {
    @State private var store: OperatorStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("op.hasShownWelcome") private var hasShownWelcome: Bool = false
    @State private var showingOnboarding: Bool = false

    init(modelContext: ModelContext) {
        _store = State(initialValue: OperatorStore(modelContext: modelContext))
    }

    var body: some View {
        platformShell
            .onAppear {
                PendingShareConsumer.consume(into: store)
                if !hasShownWelcome {
                    showingOnboarding = true
                }
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingSheet(
                    onTour: {
                        store.populateSampleRecords()
                        hasShownWelcome = true
                        showingOnboarding = false
                    },
                    onStart: {
                        hasShownWelcome = true
                        showingOnboarding = false
                    }
                )
                .interactiveDismissDisabled()
            }
    }

    @ViewBuilder
    private var platformShell: some View {
        #if os(macOS)
        MacShellView(store: store)
        #else
        if horizontalSizeClass == .regular {
            IPadShellView(store: store)
        } else {
            RootTabView(store: store)
        }
        #endif
    }
}
