// MARK: - LoopBodyPickerSheet
//
// Modal sheet for choosing which modules sit inside a Loop's body
// (Michael 2026-05-20). Lists every brick in the same Gantt chart
// — Timer, Gate, Supplemental — with a checkbox next to each. The
// loop's `containedBrickIds` is updated when the user taps Done.
//
// Used by SupplementalBrickView's Loop card via a sheet
// presentation triggered by the "Manage" button.

import SwiftUI
import SwiftData

struct LoopBodyPickerSheet: View {
    @Bindable var loop: SupplementalBrickData

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var timers:        [TimerModuleData]
    @Query private var gates:         [GateBrickData]
    @Query private var supplementals: [SupplementalBrickData]

    /// Local working copy of the loop's contained-ID set so the user
    /// can Cancel without persisting.
    @State private var draftIds: Set<UUID> = []

    init(loop: SupplementalBrickData) {
        self.loop = loop
        // Scope queries to the loop's chart so we only pick from
        // siblings of the loop itself.
        let chartId = loop.ganttChartId
        _timers = Query(
            filter: #Predicate<TimerModuleData> { $0.ganttChartId == chartId }
        )
        _gates = Query(
            filter: #Predicate<GateBrickData> { $0.ganttChartId == chartId }
        )
        _supplementals = Query(
            filter: #Predicate<SupplementalBrickData> { $0.ganttChartId == chartId }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if !timers.isEmpty {
                    Section("Timers") {
                        ForEach(timers) { timer in
                            row(
                                id: timer.id,
                                label: timer.notation.isEmpty ? "Timer" : timer.notation,
                                systemImage: "clock"
                            )
                        }
                    }
                }
                if !gates.isEmpty {
                    Section("Logic gates") {
                        ForEach(gates) { gate in
                            row(
                                id: gate.id,
                                label: gate.gateType.displayName,
                                systemImage: "triangle"
                            )
                        }
                    }
                }
                let otherSupplementals = supplementals.filter { $0.id != loop.id }
                if !otherSupplementals.isEmpty {
                    Section("Other modules") {
                        ForEach(otherSupplementals) { sup in
                            row(
                                id: sup.id,
                                label: sup.notation.isEmpty ? sup.brickType.displayName : sup.notation,
                                systemImage: sup.brickType.symbolName ?? "square"
                            )
                        }
                    }
                }
            }
            .navigationTitle("Loop body")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        loop.containedBrickIds = Array(draftIds)
                        loop.updatedDate = Date()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear { draftIds = Set(loop.containedBrickIds) }
        .frame(minWidth: 420, minHeight: 420)
    }

    @ViewBuilder
    private func row(id: UUID, label: String, systemImage: String) -> some View {
        let isIncluded = draftIds.contains(id)
        Button {
            if isIncluded {
                draftIds.remove(id)
            } else {
                draftIds.insert(id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isIncluded ? Color.accentColor : .secondary)
                    .font(.system(size: 18))
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
