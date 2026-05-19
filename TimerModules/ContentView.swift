import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerModuleData.order) private var timers: [TimerModuleData]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let first = timers.first {
                    TimerModuleBrickView(data: first)
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(.regularMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No timer yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button {
                let new = TimerModuleData(notation: "Timer", order: 0)
                modelContext.insert(new)
            } label: {
                Label("Add a Timer", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.top, 60)
    }
}
