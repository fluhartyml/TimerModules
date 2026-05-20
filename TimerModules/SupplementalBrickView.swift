// MARK: - SupplementalBrickView
//
// Renders one of the nine supplemental brick types as a
// configurable card on the Gantt canvas. The view dispatches on
// `data.brickType` to a per-type config UI.
//
// Each brick gets the same header (icon, name, notation
// TextField) and then a type-specific body.

import SwiftUI
import SwiftData

struct SupplementalBrickView: View {
    @Bindable var data: SupplementalBrickData
    @Environment(\.modelContext) private var modelContext

    /// Invoked when the user taps the note.text glyph (Michael
    /// 2026-05-20). Parent (GanttCanvasView) owns the editor sheet.
    var onEditNoteTapped: () -> Void = {}

    private var brickType: BrickType { data.brickType }

    var body: some View {
        if brickType == .endBrick {
            // End cards are a fraction of the standard supplemental
            // size (Michael 2026-05-20: "space is premium" — the
            // whole card means "program stops here," so it doesn't
            // need a header, body, or notation field; the red stop
            // glyph + the word "End" carry the meaning).
            compactEndCard
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                typeSpecificBody
                notationField
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(brickColor.opacity(0.4), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                noteGlyphButton.padding(6)
            }
        }
    }

    // MARK: Compact End card

    private var compactEndCard: some View {
        VStack(spacing: 4) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            Text("End")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.red)
        }
        .padding(8)
        .frame(width: 76)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.4), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            noteGlyphButton.padding(2)
        }
    }

    // MARK: Note glyph button (Michael 2026-05-20)
    //
    // Always visible. Subtle grey when no note exists; saturated
    // cyan when the module has notes. Tap → opens the note editor.

    private var noteGlyphButton: some View {
        Button {
            onEditNoteTapped()
        } label: {
            Image(systemName: "note.text")
                .font(.system(size: brickType == .endBrick ? 11 : 14, weight: .semibold))
                .foregroundStyle(
                    data.note.isEmpty
                        ? AnyShapeStyle(Color.secondary.opacity(0.35))
                        : AnyShapeStyle(Color.cyan)
                )
                .frame(
                    width: brickType == .endBrick ? 22 : 28,
                    height: brickType == .endBrick ? 22 : 28
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(data.note.isEmpty ? "Add note" : "Edit note")
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: brickType.symbolName ?? "square")
                .font(.system(size: 22))
                .foregroundStyle(brickColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(brickType.displayName)
                    .font(.headline)
                Text(typeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var typeDescription: String {
        switch brickType {
        case .note:         return "Annotation"
        case .marker:       return "Milestone marker"
        case .trigger:      return "Entry point"
        case .action:       return "Side effect"
        case .group:        return "Container"
        case .variable:     return "Counter"
        case .webhook:      return "HTTP outbound"
        case .conditional:  return "If / Else"
        case .loop:         return "Repeat"
        case .endBrick:     return "Program end"
        default:            return ""
        }
    }

    // MARK: Type-specific body

    @ViewBuilder
    private var typeSpecificBody: some View {
        switch brickType {
        case .note:        noteBody
        case .marker:      markerBody
        case .trigger:     triggerBody
        case .action:      actionBody
        case .group:       groupBody
        case .variable:    variableBody
        case .webhook:     webhookBody
        case .conditional: conditionalBody
        case .loop:        loopBody
        case .endBrick:    endBody
        default:           EmptyView()
        }
    }

    // MARK: End

    private var endBody: some View {
        VStack(spacing: 10) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text("Program ends here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("When the program flow reaches this brick, the run halts and the summary opens.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
    }

    // MARK: Note

    private var noteBody: some View {
        TextField("Type your note…", text: $data.textContent, axis: .vertical)
            .lineLimit(3...6)
            .font(.system(size: 16))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.08))
            )
    }

    // MARK: Marker

    private var markerBody: some View {
        HStack {
            Image(systemName: "diamond.fill")
                .foregroundStyle(Color(hex: data.markerColorHex) ?? .yellow)
                .font(.system(size: 36))
            Spacer()
            ColorPicker("Color", selection: Binding(
                get: { Color(hex: data.markerColorHex) ?? .yellow },
                set: { data.markerColorHex = $0.toHex() ?? "#FFB000" }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    // MARK: Trigger

    private var triggerBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Kind", selection: $data.kindRaw) {
                Text("Manual").tag("manual")
                Text("Scheduled").tag("scheduled")
                Text("External").tag("external")
            }
            .pickerStyle(.segmented)

            if data.kindRaw == "scheduled" {
                TextField("Schedule (e.g. daily 9am, every Monday)…",
                          text: $data.configString)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
            }

            Button {
                fireTrigger()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private func fireTrigger() {
        data.updatedDate = Date()
        SignalRouter.fireProgram(from: data, in: modelContext)
    }

    // MARK: Action

    private var actionBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Kind", selection: $data.kindRaw) {
                Text("Sound").tag("sound")
                Text("Notification").tag("notification")
                Text("Log entry").tag("log")
                Text("Deep link").tag("link")
            }
            .pickerStyle(.menu)

            if data.kindRaw == "sound" {
                soundPicker
            } else {
                TextField(actionConfigPlaceholder, text: $data.configString)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
            }
        }
    }

    /// Picker of curated predefined iOS sounds (Michael 2026-05-19).
    /// Selected sound name is stored in configString so the
    /// SignalRouter can look it up at fire time.
    private var soundPicker: some View {
        Picker("Sound", selection: Binding(
            get: { ActionSound(rawValue: data.configString) ?? .default },
            set: { data.configString = $0.rawValue }
        )) {
            ForEach(ActionSound.allCases) { sound in
                Text(sound.rawValue).tag(sound)
            }
        }
        .pickerStyle(.menu)
    }

    private var actionConfigPlaceholder: String {
        switch data.kindRaw {
        case "notification":  return "Notification message"
        case "log":           return "Log message"
        case "link":          return "URL to open"
        default:              return "Config"
        }
    }

    // MARK: Group

    private var groupBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(data.containedBrickIds.count) brick(s) grouped")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Tap a brick to add to this group (signal-routing layer wires this up).")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Variable

    private var variableBody: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Value").foregroundStyle(.secondary)
                Spacer()
                Text("\(data.variableValue, specifier: "%.0f")")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 8) {
                Button {
                    data.variableValue -= 1
                    data.updatedDate = Date()
                } label: {
                    Image(systemName: "minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    data.variableValue += 1
                    data.updatedDate = Date()
                } label: {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    data.variableValue = data.variableInitial
                    data.updatedDate = Date()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)

            HStack {
                Text("Initial").foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: $data.variableInitial,
                    in: -1000...1000,
                    step: 1
                ) {
                    Text("\(data.variableInitial, specifier: "%.0f")")
                        .monospacedDigit()
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: Webhook

    private var webhookBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Method", selection: $data.kindRaw) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("DELETE").tag("DELETE")
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                Spacer()
            }

            TextField("https://…", text: $data.configString)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .monospaced))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            if data.kindRaw != "GET" {
                TextField("Request body (JSON or form-encoded)",
                          text: $data.bodyContent, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
        }
    }

    // MARK: Conditional

    private var conditionalBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Condition")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField("e.g. variable > 5", text: $data.textContent)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)

            HStack {
                VStack(alignment: .leading) {
                    Text("True branch")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("\(data.containedBrickIds.count) brick(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("False branch")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("\(data.alternateBrickIds.count) brick(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Loop
    //
    // Until-signal Loop (Michael 2026-05-20). No repeat count — the
    // loop runs its body in a tight cycle and halts when ANY wired
    // upstream signal arrives. The user composes the halt condition
    // OUTSIDE the loop (e.g. a Work-Day countdown timer wired to the
    // loop's left edge becomes the halt source; AND/OR gates compose
    // multi-source halt conditions).
    //
    // The `loopCount` field on SupplementalBrickData stays in the
    // model dormant for SwiftData migration safety; it's not read
    // anywhere in code anymore.

    @State private var showingLoopBodyPicker = false

    private var loopBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.brown)
                Text("Runs until halt signal arrives")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text("Body:")
                    .foregroundStyle(.secondary)
                Text("\(data.containedBrickIds.count) module\(data.containedBrickIds.count == 1 ? "" : "s")")
                    .monospacedDigit()
                Spacer()
                Button {
                    showingLoopBodyPicker = true
                } label: {
                    Label("Manage", systemImage: "rectangle.stack.badge.plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .font(.subheadline)

            if data.containedBrickIds.isEmpty {
                Text("Tap Manage to choose which modules re-fire each iteration.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showingLoopBodyPicker) {
            LoopBodyPickerSheet(loop: data)
        }
    }

    // MARK: Notation field (shared)

    private var notationField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Label this brick", text: $data.notation)
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
                .stroke(brickColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Color per supplemental type

    private var brickColor: Color {
        switch brickType {
        case .note:         return .purple
        case .marker:       return .yellow
        case .trigger:      return .green
        case .action:       return .pink
        case .group:        return .gray
        case .variable:     return .mint
        case .webhook:      return .cyan
        case .conditional:  return .indigo
        case .loop:         return .brown
        case .endBrick:     return .red
        default:            return .gray
        }
    }
}

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt64(h, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8)  & 0xFF) / 255.0
        let b = Double( v        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        // SwiftUI's Color doesn't expose RGB components directly across
        // platforms. We round-trip via the resolved color where we can.
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
        #else
        return nil
        #endif
    }
}
