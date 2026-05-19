// MARK: - TraceBrickView
//
// Renders one PM-dependency trace as a configurable row on the
// canvas. Pickers let the user set the source brick and the
// destination brick(s); a stepper sets the lag/lead offset.
//
// The visual edge between source and destination is drawn by the
// GanttCanvasView's overlay layer once both ends are configured —
// this row brick is the "control panel" for the trace.

import SwiftUI
import SwiftData

struct TraceBrickView: View {
    @Bindable var data: TraceData

    /// All timer bricks the user has placed — candidates for source/dest.
    let timerCandidates: [TimerModuleData]
    /// All gate bricks the user has placed — candidates for source/dest.
    let gateCandidates: [GateBrickData]

    private var traceType: BrickType { data.traceType }
    private var isSplitter: Bool { traceType == .splitter }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            typePickerRow
            sourcePickerRow
            destinationPickerRow
            lagStepperRow

            notationField
        }
        .padding(18)
        .frame(maxWidth: 360)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(traceColor.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: Type picker — the trace's adjustable relationship type.

    private var typePickerRow: some View {
        HStack {
            Text("Type").foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Menu {
                Button("FS · Finish → Start") { setTraceType(.fsEdge) }
                Button("SS · Start → Start")  { setTraceType(.ssEdge) }
                Button("FF · Finish → Finish") { setTraceType(.ffEdge) }
                Button("SF · Start → Finish")  { setTraceType(.sfEdge) }
            } label: {
                HStack {
                    Text(currentTypeShortLabel)
                        .foregroundStyle(Color.accentColor)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }
            Spacer()
        }
        .font(.subheadline)
    }

    private var currentTypeShortLabel: String {
        switch traceType {
        case .fsEdge: return "FS · Finish → Start"
        case .ssEdge: return "SS · Start → Start"
        case .ffEdge: return "FF · Finish → Finish"
        case .sfEdge: return "SF · Start → Finish"
        default:      return "FS · Finish → Start"
        }
    }

    private func setTraceType(_ type: BrickType) {
        data.traceTypeRaw = type.rawValue
        data.updatedDate = Date()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: traceType.symbolName ?? "arrow.right")
                .font(.system(size: 22))
                .foregroundStyle(traceColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(traceType.displayName)
                    .font(.headline)
                Text(traceTypeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            wiredIndicator
        }
    }

    private var traceTypeDescription: String {
        switch traceType {
        case .fsEdge:   return "Finish → Start"
        case .ssEdge:   return "Start → Start"
        case .ffEdge:   return "Finish → Finish"
        case .sfEdge:   return "Start → Finish"
        case .lagLead:  return "Offset edge"
        case .splitter: return "Fan-out · one → many"
        default:        return ""
        }
    }

    private var wiredIndicator: some View {
        Image(systemName: data.isWired ? "checkmark.circle.fill" : "circle.dotted")
            .foregroundStyle(data.isWired ? Color.green : Color.secondary)
            .font(.system(size: 18))
            .help(data.isWired ? "Trace is fully wired" : "Pick source + destination")
    }

    // MARK: Pickers

    private var sourcePickerRow: some View {
        HStack {
            Text("From").foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Menu {
                Button("None") { data.sourceBrickId = nil }
                Divider()
                ForEach(timerCandidates, id: \.id) { t in
                    Button(timerLabel(t)) { data.sourceBrickId = t.id }
                }
                if !gateCandidates.isEmpty {
                    Divider()
                    ForEach(gateCandidates, id: \.id) { g in
                        Button(gateLabel(g)) { data.sourceBrickId = g.id }
                    }
                }
            } label: {
                HStack {
                    Text(sourceLabel)
                        .foregroundStyle(data.sourceBrickId == nil ? Color.secondary : Color.accentColor)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }
            Spacer()
        }
        .font(.subheadline)
    }

    private var destinationPickerRow: some View {
        HStack(alignment: .top) {
            Text(isSplitter ? "To (many)" : "To")
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Menu {
                    if !isSplitter {
                        Button("None") { data.destinationBrickIds = [] }
                        Divider()
                    }
                    ForEach(timerCandidates, id: \.id) { t in
                        Button(timerLabel(t)) { toggleDestination(t.id) }
                    }
                    if !gateCandidates.isEmpty {
                        Divider()
                        ForEach(gateCandidates, id: \.id) { g in
                            Button(gateLabel(g)) { toggleDestination(g.id) }
                        }
                    }
                } label: {
                    HStack {
                        Text(destinationLabel)
                            .foregroundStyle(data.destinationBrickIds.isEmpty ? Color.secondary : Color.accentColor)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            }
            Spacer()
        }
        .font(.subheadline)
    }

    private var lagStepperRow: some View {
        HStack {
            Text("Lag/Lead").foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Spacer()
            Stepper(
                value: Binding(
                    get: { Int(data.lagSeconds) },
                    set: { data.lagSeconds = TimeInterval($0) }
                ),
                in: -3600...3600,
                step: 5
            ) {
                Text("\(Int(data.lagSeconds))s")
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
    }

    private var notationField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Label this trace", text: $data.notation)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
                .submitLabel(.done)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(traceColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Helpers

    private var sourceLabel: String {
        guard let sid = data.sourceBrickId else { return "Pick source…" }
        if let t = timerCandidates.first(where: { $0.id == sid }) { return timerLabel(t) }
        if let g = gateCandidates.first(where: { $0.id == sid }) { return gateLabel(g) }
        return "Pick source…"
    }

    private var destinationLabel: String {
        if data.destinationBrickIds.isEmpty { return isSplitter ? "Pick destinations…" : "Pick destination…" }
        let names: [String] = data.destinationBrickIds.compactMap { id in
            if let t = timerCandidates.first(where: { $0.id == id }) { return timerLabel(t) }
            if let g = gateCandidates.first(where: { $0.id == id }) { return gateLabel(g) }
            return nil
        }
        return names.joined(separator: ", ")
    }

    private func timerLabel(_ t: TimerModuleData) -> String {
        t.notation.isEmpty ? "Timer (row \(t.order + 1))" : t.notation
    }

    private func gateLabel(_ g: GateBrickData) -> String {
        let name = g.gateType.displayName
        return g.notation.isEmpty ? "\(name) (row \(g.order + 1))" : "\(name): \(g.notation)"
    }

    private func toggleDestination(_ id: UUID) {
        if isSplitter {
            if let idx = data.destinationBrickIds.firstIndex(of: id) {
                data.destinationBrickIds.remove(at: idx)
            } else {
                data.destinationBrickIds.append(id)
            }
        } else {
            data.destinationBrickIds = [id]
        }
    }

    /// Color-codes trace bricks by family.
    private var traceColor: Color {
        switch traceType {
        case .fsEdge, .ssEdge, .ffEdge, .sfEdge: return .blue
        case .lagLead:                            return .purple
        case .splitter:                           return .teal
        default:                                  return .gray
        }
    }
}
