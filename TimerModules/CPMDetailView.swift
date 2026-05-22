// MARK: - CPMDetailView
//
// Full-screen detail sheet for a CPM. The 4×4 CPM body on the canvas
// is too small to fit a complete Smart Stack — tapping the body opens
// this sheet, which hosts the five locked Smart Stack faces:
//   1. Calendar grid (month view, port-bound dates highlighted)
//   2. Event grid (3-column table — primary editing surface)
//   3. Port roster (reverse view, ports 1-52)
//   4. Next-firings preview (chronological list)
//   5. Year heatmap (stretch — present but minimal)
//
// Phase 4 ships Face 2 fully (event CRUD); faces 1, 3, 4, 5 ship as
// stub views that read but don't edit. Per-event recurrence editing
// happens via the CPMEventEditorView sheet presented on row tap.

import SwiftUI
import SwiftData

struct CPMDetailView: View {
    let data: CPMBrickData

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// CPMEvents owned by this CPM, queried by foreign-key UUID.
    @Query private var ownedEvents: [CPMEvent]

    /// Currently-presented Smart Stack face.
    @State private var selectedFace: Int = 1

    /// Event currently being edited (sheet presentation target).
    /// nil = no editor visible. Used both for "add new" and "edit existing"
    /// — add passes a freshly-created CPMEvent; edit passes the tapped row.
    @State private var editingEvent: CPMEvent?

    init(data: CPMBrickData) {
        self.data = data
        let cpmId = data.id
        _ownedEvents = Query(
            filter: #Predicate<CPMEvent> { $0.ownerCPMId == cpmId },
            sort: \CPMEvent.eventName
        )
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedFace) {
                calendarGridFace.tag(1)
                eventGridFace.tag(2)
                portRosterFace.tag(3)
                nextFiringsFace.tag(4)
                yearHeatmapFace.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("Calendar Processing Module")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if selectedFace == 2 {
                        Button {
                            startAddingEvent()
                        } label: {
                            Label("Add event", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(item: $editingEvent) { event in
                CPMEventEditorView(event: event)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Face 1 — Calendar grid (stub)

    private var calendarGridFace: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Face 1 — Calendar grid")
                .font(.title3)
            Text("Month view with port-bound dates highlighted ships in a later iteration.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Face 2 — Event grid (primary editing surface)

    private var eventGridFace: some View {
        Group {
            if ownedEvents.isEmpty {
                emptyEventsState
            } else {
                eventList
            }
        }
    }

    private var emptyEventsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No events yet")
                .font(.title2)
            Text("Press + to add your first event.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventList: some View {
        List {
            ForEach(ownedEvents) { event in
                Button {
                    editingEvent = event
                } label: {
                    eventRow(event)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteEvents)
        }
    }

    private func eventRow(_ event: CPMEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.eventName.isEmpty ? "Untitled event" : event.eventName)
                    .font(.headline)
                if !event.briefDescription.isEmpty {
                    Text(event.briefDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(portsLabel(event.portNumbers))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(event.portNumbers.isEmpty ? .secondary : .primary)
                if !event.notifyEnabled {
                    Image(systemName: "bell.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func portsLabel(_ ports: [Int]) -> String {
        guard !ports.isEmpty else { return "—" }
        return "Port " + ports.sorted().map(String.init).joined(separator: ", ")
    }

    private func startAddingEvent() {
        let new = CPMEvent(
            ownerCPMId: data.id,
            eventName: "",
            briefDescription: "",
            portNumbers: []
        )
        modelContext.insert(new)
        editingEvent = new
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(ownedEvents[index])
        }
    }

    // MARK: Face 3 — Port roster (stub)

    private var portRosterFace: some View {
        List {
            ForEach(1...CPMBrickData.portCount, id: \.self) { port in
                HStack {
                    Text("Port \(port)")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    let firingEvents = ownedEvents.filter { $0.portNumbers.contains(port) }
                    if firingEvents.isEmpty {
                        Text("idle")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("\(firingEvents.count) event\(firingEvents.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Face 4 — Next firings (stub)

    private var nextFiringsFace: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Face 4 — Next firings preview")
                .font(.title3)
            Text("Chronological list of upcoming event firings ships once recurrence resolution lands (Phase 5).")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Face 5 — Year heatmap (stub, locked as stretch)

    private var yearHeatmapFace: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.4x3.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Face 5 — Year heatmap")
                .font(.title3)
            Text("Stretch feature (locked Section C). Ships if there's room in v1.0, skipped otherwise.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
