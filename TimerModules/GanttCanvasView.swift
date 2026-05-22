// MARK: - GanttCanvasView
//
// The Gantt canvas — 2D grid where bricks live. Scoped to one
// Gantt chart via `chartId`; all @Queries filter by that.
//
// Layout (Michael 2026-05-19 — "the user defines how many
// colums the user needs"):
//   • Vertical axis = rows (`order` field). Lower = higher up.
//   • Horizontal axis = columns (`column` field). 0 = leftmost.
//   • Same row + different columns = sequential (in time).
//   • Different rows + same column = parallel/simultaneous.
//   • Each row has a "+ here" drop zone at its right end so
//     users can add to existing rows.
//   • "+ new row" drop zone at the bottom adds a new row.
//
// M2 wires .timerModule.
// M3 wires the seven boolean logic gates.
// M4 unifies the trace brick.
// M5 wires the nine supplemental types.
// M5.5 adds multi-chart filtering + 2D grid + signal routing
//   + execution log (this file = the chart-filtering + grid).

import SwiftUI
import SwiftData

struct GanttCanvasView: View {
    let chartId: UUID
    let columnCount: Int

    /// Shared tap-to-wire coordinator with BrickPaletteView (M5.7).
    /// When wiring.isWiring is true, bricks become tappable for
    /// source/destination selection instead of operating normally.
    @Bindable var wiring: WiringState

    @Environment(\.modelContext) private var modelContext

    @Query private var timers:        [TimerModuleData]
    @Query private var gates:         [GateBrickData]
    @Query private var traces:        [TraceData]
    @Query private var supplementals: [SupplementalBrickData]
    @Query private var starts:        [StartBrickData]
    @Query private var delays:        [DelayBrickData]
    @Query private var textLCDs:      [TextLCDBrickData]
    @Query private var glyphLCDs:     [GlyphLCDBrickData]
    @Query private var digitalClocks: [DigitalClockBrickData]
    @Query private var calendarDates: [CalendarDateBrickData]
    @Query private var batteries:     [BatteryBrickData]
    @Query private var noteModules:   [NoteModuleBrickData]
    @Query private var weatherBricks: [WeatherBrickData]
    @Query private var cpms:          [CPMBrickData]

    @State private var brickFrames: [UUID: CGRect] = [:]
    @State private var dropTargetedRow: Int? = nil
    @State private var dropTargetedNewRow: Bool = false

    /// Currently-open note editor target, if any (Michael 2026-05-20).
    /// Set when the user taps a module's note.text glyph button or
    /// chooses "Edit note…" from its long-press / right-click menu.
    @State private var noteEditorTarget: NoteEditorTarget? = nil

    // Pinch zoom is handled by `ZoomableCanvas` (UIScrollView /
    // NSScrollView wrapper). The earlier SwiftUI .scaleEffect +
    // MagnifyGesture attempt couldn't reconcile zoom with content
    // bounds — pan stopped reaching the corners of zoomed content
    // (Michael 2026-05-20: "the scrolll bars were zooming in and
    // zooming out and not scrolling"). The native scroll views
    // handle both gestures correctly.

    /// Identifiable wrapper around an open note-editor session so a
    /// single `.sheet(item:)` modifier on the canvas can present the
    /// editor for any brick type.
    private struct NoteEditorTarget: Identifiable {
        let id: UUID
        let title: String
        let initialNote: String
        let onSave: (String) -> Void
    }

    init(chartId: UUID, columnCount: Int, wiring: WiringState) {
        self.chartId = chartId
        self.columnCount = columnCount
        self.wiring = wiring

        let id = chartId
        _timers = Query(
            filter: #Predicate<TimerModuleData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
        _gates = Query(
            filter: #Predicate<GateBrickData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
        _traces = Query(
            filter: #Predicate<TraceData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
        _supplementals = Query(
            filter: #Predicate<SupplementalBrickData> { $0.ganttChartId == id },
            sort: [SortDescriptor(\.order), SortDescriptor(\.column)]
        )
    }

    /// Polymorphic wrapper so renderable bricks can share a render
    /// loop. Per M5.7 (Michael 2026-05-19), traces no longer render
    /// as rows — they live purely as overlay edges drawn between
    /// brick frames in `traceEdgeOverlay`. Only Timer, Gate, and
    /// Supplemental bricks render in the grid.
    private enum CanvasBrick: Identifiable {
        case timer(TimerModuleData)
        case gate(GateBrickData)
        case supplemental(SupplementalBrickData)
        case start(StartBrickData)
        case delay(DelayBrickData)
        case textLCD(TextLCDBrickData)
        case glyphLCD(GlyphLCDBrickData)
        case digitalClock(DigitalClockBrickData)
        case calendarDate(CalendarDateBrickData)
        case battery(BatteryBrickData)
        case noteModule(NoteModuleBrickData)
        case weather(WeatherBrickData)
        case cpm(CPMBrickData)

        var id: UUID {
            switch self {
            case .timer(let t):           return t.id
            case .gate(let g):            return g.id
            case .supplemental(let s):    return s.id
            case .start(let st):          return st.id
            case .delay(let d):           return d.id
            case .textLCD(let l):         return l.id
            case .glyphLCD(let gl):       return gl.id
            case .digitalClock(let dc):   return dc.id
            case .calendarDate(let cd):   return cd.id
            case .battery(let b):         return b.id
            case .noteModule(let n):      return n.id
            case .weather(let w):         return w.id
            case .cpm(let c):             return c.id
            }
        }

        var row: Int {
            switch self {
            case .timer(let t):           return t.order
            case .gate(let g):            return g.order
            case .supplemental(let s):    return s.order
            case .start(let st):          return st.order
            case .delay(let d):           return d.order
            case .textLCD(let l):         return l.order
            case .glyphLCD(let gl):       return gl.order
            case .digitalClock(let dc):   return dc.order
            case .calendarDate(let cd):   return cd.order
            case .battery(let b):         return b.order
            case .noteModule(let n):      return n.order
            case .weather(let w):         return w.order
            case .cpm(let c):             return c.order
            }
        }

        var column: Int {
            switch self {
            case .timer(let t):           return t.column
            case .gate(let g):            return g.column
            case .supplemental(let s):    return s.column
            case .start(let st):          return st.column
            case .delay(let d):           return d.column
            case .textLCD(let l):         return l.column
            case .glyphLCD(let gl):       return gl.column
            case .digitalClock(let dc):   return dc.column
            case .calendarDate(let cd):   return cd.column
            case .battery(let b):         return b.column
            case .noteModule(let n):      return n.column
            case .weather(let w):         return w.column
            case .cpm(let c):             return c.column
            }
        }
    }

    private var allBricks: [CanvasBrick] {
        let t   = timers.map        { CanvasBrick.timer($0) }
        let g   = gates.map         { CanvasBrick.gate($0) }
        let s   = supplementals.map { CanvasBrick.supplemental($0) }
        let st  = starts.map        { CanvasBrick.start($0) }
        let d   = delays.map        { CanvasBrick.delay($0) }
        let lc  = textLCDs.map      { CanvasBrick.textLCD($0) }
        let glc = glyphLCDs.map     { CanvasBrick.glyphLCD($0) }
        let dc  = digitalClocks.map { CanvasBrick.digitalClock($0) }
        let cd  = calendarDates.map { CanvasBrick.calendarDate($0) }
        let bt  = batteries.map     { CanvasBrick.battery($0) }
        let nm  = noteModules.map   { CanvasBrick.noteModule($0) }
        let w   = weatherBricks.map { CanvasBrick.weather($0) }
        let cp  = cpms.map          { CanvasBrick.cpm($0) }
        return t + g + s + st + d + lc + glc + dc + cd + bt + nm + w + cp
    }

    /// Bricks grouped by row, with each row's bricks sorted by column.
    private var bricksByRow: [(row: Int, bricks: [CanvasBrick])] {
        let grouped = Dictionary(grouping: allBricks, by: \.row)
        return grouped
            .map { (row: $0.key, bricks: $0.value.sorted { $0.column < $1.column }) }
            .sorted { $0.row < $1.row }
    }

    var body: some View {
        ZoomableCanvas {
            VStack(alignment: .leading, spacing: 14) {
                if bricksByRow.isEmpty {
                    emptyCanvasHint
                        .dropDestination(for: BrickType.self) { items, _ in
                            handleDrop(items, targetRow: 0, targetColumn: 0)
                        } isTargeted: { targeted in
                            dropTargetedNewRow = targeted
                        }
                } else {
                    ForEach(bricksByRow, id: \.row) { row in
                        rowContainer(rowIndex: row.row, bricks: row.bricks)
                    }
                }

                addNewRowDropZone
            }
            .padding(20)
            // Traces and × delete handles live INSIDE the zoomable
            // hosted view so they pan and zoom together with the
            // cards they reference.
            .overlay(alignment: .topLeading) {
                traceEdgeOverlay
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                traceDeleteHandles
            }
            // The coordinate space and preference listener MUST sit
            // inside the ZoomableCanvas closure — SwiftUI preferences
            // don't propagate across a UIHostingController boundary,
            // so a listener outside the wrapper never receives the
            // brick frames and the trace overlay would draw using
            // stale data (Michael 2026-05-20: "the traces get loose
            // and arnt attached to their modules during pinch zoom").
            .coordinateSpace(name: "ganttCanvas")
            .onPreferenceChange(BrickFramePreferenceKey.self) { newValue in
                brickFrames = newValue
            }
        }
        .background(canvasBackground)
        .sheet(item: $noteEditorTarget) { target in
            NoteEditorSheet(
                title: target.title,
                initialNote: target.initialNote,
                onSave: target.onSave
            )
        }
        // NOTE: the auto-scroll-to-active-row feature that used
        // `ScrollViewReader.scrollTo` is removed in this revision
        // because `ZoomableCanvas` wraps a native UI/NSScrollView,
        // not a SwiftUI ScrollView. Follow-up: expose a
        // `scrollTo(rowId:)` programmatic API on ZoomableCanvas so
        // this can be re-enabled. (Michael 2026-05-20.)
    }

    /// The lowest-numbered row that currently has a running timer.
    /// nil when no timers are running. Drives auto-scroll focus.
    private var activeRunningRow: Int? {
        timers
            .filter { $0.runningSince != nil }
            .map(\.order)
            .min()
    }

    // MARK: Background

    private var canvasBackground: some View {
        Color.gray.opacity(0.06)
    }

    // MARK: Empty state

    private var emptyCanvasHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Drag a brick here to start your Timer Module")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Stack rows vertically for parallel tracks; line bricks up horizontally for sequence.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    dropTargetedNewRow ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
    }

    // MARK: Row container

    private func rowContainer(rowIndex: Int, bricks: [CanvasBrick]) -> some View {
        let isActive = (activeRunningRow == rowIndex)
        return HStack(alignment: .top, spacing: 10) {
            rowHandle(rowIndex)

            ForEach(bricks) { brick in
                brickContent(for: brick)
                    .reportBrickFrame(id: brick.id)
            }

            addToRowDropZone(rowIndex)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isActive ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }

    private func rowHandle(_ rowIndex: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(rowIndex + 1)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(.thinMaterial)
                )
            Text("Row")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func brickContent(for brick: CanvasBrick) -> some View {
        switch brick {
        case .timer(let timer):
            TimerModuleBrickView(
                data: timer,
                onEditNoteTapped: { openNoteEditorForTimer(timer) }
            )
            .wiringOverlay(id: timer.id, wiring: wiring) { tappedBrick(timer.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForTimer(timer) }
                deleteMenuItem(for: brick)
            }
        case .gate(let gate):
            GateBrickView(
                data: gate,
                onEditNoteTapped: { openNoteEditorForGate(gate) }
            )
            .wiringOverlay(id: gate.id, wiring: wiring) { tappedBrick(gate.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForGate(gate) }
                deleteMenuItem(for: brick)
            }
        case .supplemental(let sup):
            SupplementalBrickView(
                data: sup,
                onEditNoteTapped: { openNoteEditorForSupplemental(sup) }
            )
            .wiringOverlay(id: sup.id, wiring: wiring) { tappedBrick(sup.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForSupplemental(sup) }
                deleteMenuItem(for: brick)
            }
        case .start(let st):
            StartBrickView(
                data: st,
                onEditNoteTapped: { openNoteEditorForStart(st) },
                onStartTapped: {
                    SignalRouter.fireProgramFromStart(st, in: modelContext)
                }
            )
            .wiringOverlay(id: st.id, wiring: wiring) { tappedBrick(st.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForStart(st) }
                deleteMenuItem(for: brick)
            }
        case .delay(let d):
            DelayBrickView(
                data: d,
                onEditNoteTapped: { openNoteEditorForDelay(d) }
            )
            .wiringOverlay(id: d.id, wiring: wiring) { tappedBrick(d.id) }
            .contextMenu {
                Text("Delay: \(d.heldSeconds) sec (display \(d.displayValue))")
                Divider()
                ForEach(0...9, id: \.self) { v in
                    Button("Set to \(v + 1) sec") {
                        d.displayValue = v
                        d.updatedDate = Date()
                    }
                }
                Divider()
                Button("Rename…") { openRenameEditorForDelay(d) }
                editNoteMenuItem { openNoteEditorForDelay(d) }
                deleteMenuItem(for: brick)
            }
        case .textLCD(let l):
            TextLCDBrickView(
                data: l,
                onEditNoteTapped: { openNoteEditorForTextLCD(l) }
            )
            .wiringOverlay(id: l.id, wiring: wiring) { tappedBrick(l.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForTextLCD(l) }
                Button("Edit canned messages…") {
                    openCannedMessagesEditor(for: l)
                }
                deleteMenuItem(for: brick)
            }
        case .glyphLCD(let gl):
            GlyphLCDBrickView(
                data: gl,
                onEditNoteTapped: { openNoteEditorForGlyphLCD(gl) }
            )
            .wiringOverlay(id: gl.id, wiring: wiring) { tappedBrick(gl.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForGlyphLCD(gl) }
                Button("Edit glyphs…") {
                    openGlyphsEditor(for: gl)
                }
                deleteMenuItem(for: brick)
            }
        case .digitalClock(let dc):
            DigitalClockBrickView(
                data: dc,
                onEditNoteTapped: { openNoteEditorForDigitalClock(dc) }
            )
            .wiringOverlay(id: dc.id, wiring: wiring) { tappedBrick(dc.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForDigitalClock(dc) }
                Button(dc.use24HourFormat ? "Switch to 12-hour" : "Switch to 24-hour") {
                    dc.use24HourFormat.toggle()
                    dc.updatedDate = Date()
                }
                deleteMenuItem(for: brick)
            }
        case .calendarDate(let cd):
            CalendarDateBrickView(
                data: cd,
                onEditNoteTapped: { openNoteEditorForCalendarDate(cd) }
            )
            .wiringOverlay(id: cd.id, wiring: wiring) { tappedBrick(cd.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForCalendarDate(cd) }
                Menu("Date format") {
                    Button("MMM d EEE — May 21 Thu") { cd.formatStyleRaw = 0; cd.updatedDate = Date() }
                    Button("M/d/yy — 5/21/26") { cd.formatStyleRaw = 1; cd.updatedDate = Date() }
                    Button("EEE MMM d — Thu May 21") { cd.formatStyleRaw = 2; cd.updatedDate = Date() }
                }
                deleteMenuItem(for: brick)
            }
        case .battery(let b):
            BatteryBrickView(
                data: b,
                onEditNoteTapped: { openNoteEditorForBattery(b) }
            )
            .wiringOverlay(id: b.id, wiring: wiring) { tappedBrick(b.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForBattery(b) }
                deleteMenuItem(for: brick)
            }
        case .weather(let w):
            WeatherBrickView(
                data: w,
                onEditNoteTapped: { openNoteEditorForWeather(w) }
            )
            .wiringOverlay(id: w.id, wiring: wiring) { tappedBrick(w.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForWeather(w) }
                Button(w.displayInFahrenheit ? "Switch to Celsius" : "Switch to Fahrenheit") {
                    w.displayInFahrenheit.toggle()
                    w.updatedDate = Date()
                }
                deleteMenuItem(for: brick)
            }
        case .noteModule(let n):
            NoteModuleBrickView(
                data: n,
                onEditNoteTapped: { openNoteEditorForNoteModule(n) },
                onPageEditTapped: { idx in
                    openNotePageEditor(for: n, pageIndex: idx)
                },
                onLastPageReached: {
                    SignalRouter.fireNoteLastPageReached(n, in: modelContext)
                }
            )
            .wiringOverlay(id: n.id, wiring: wiring) { tappedBrick(n.id) }
            .contextMenu {
                editNoteMenuItem { openNoteEditorForNoteModule(n) }
                Button("Add page") {
                    if n.pages.count < NoteModuleBrickData.maxPages {
                        n.pages.append("")
                        n.updatedDate = Date()
                    }
                }
                Button("Remove last page") {
                    if n.pages.count > 1 {
                        n.pages.removeLast()
                        n.currentPageIndex = min(n.currentPageIndex, n.pages.count - 1)
                        n.updatedDate = Date()
                    }
                }
                Button("Edit current page…") {
                    openNotePageEditor(for: n, pageIndex: n.currentPageIndex)
                }
                deleteMenuItem(for: brick)
            }
        case .cpm(let c):
            CPMBrickView(data: c)
                .wiringOverlay(id: c.id, wiring: wiring) { tappedBrick(c.id) }
                .contextMenu {
                    deleteMenuItem(for: brick)
                }
        }
    }

    private func openNotePageEditor(for note: NoteModuleBrickData, pageIndex: Int) {
        let safeIndex = max(0, min(note.pages.count - 1, pageIndex))
        noteEditorTarget = NoteEditorTarget(
            id: note.id,
            title: "Page \(safeIndex + 1) of \(note.pages.count)",
            initialNote: note.pages[safeIndex],
            onSave: { newText in
                var pages = note.pages
                pages[safeIndex] = String(newText.prefix(NoteModuleBrickData.charLimitPerPage))
                note.pages = pages
                note.updatedDate = Date()
            }
        )
    }

    private func openGlyphsEditor(for lcd: GlyphLCDBrickData) {
        let joined = lcd.glyphs.enumerated().map { idx, g in
            "Port \(idx + 1): \(g)"
        }.joined(separator: "\n")
        noteEditorTarget = NoteEditorTarget(
            id: lcd.id,
            title: lcd.notation.isEmpty ? "Glyph LCD" : lcd.notation,
            initialNote: joined,
            onSave: { newJoined in
                let lines = newJoined.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                var glyphs: [String] = Array(repeating: "", count: GlyphLCDBrickData.portCount)
                for (i, line) in lines.prefix(GlyphLCDBrickData.portCount).enumerated() {
                    let trimmed: String
                    if let colon = line.firstIndex(of: ":") {
                        trimmed = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    } else {
                        trimmed = line.trimmingCharacters(in: .whitespaces)
                    }
                    glyphs[i] = String(trimmed.prefix(GlyphLCDBrickData.charLimit))
                }
                lcd.glyphs = glyphs
                lcd.updatedDate = Date()
            }
        )
    }

    private func openCannedMessagesEditor(for lcd: TextLCDBrickData) {
        // For v1.0, expose the four canned slots through the same
        // NoteEditorSheet infrastructure but pre-formatted so each
        // line is one canned message. The user edits the joined
        // text; on save we split back into the 4 slots.
        let joined = lcd.cannedMessages.enumerated().map { idx, msg in
            "Port \(idx + 1): \(msg)"
        }.joined(separator: "\n")
        noteEditorTarget = NoteEditorTarget(
            id: lcd.id,
            title: lcd.notation.isEmpty ? "Text LCD" : lcd.notation,
            initialNote: joined,
            onSave: { newJoined in
                // Parse "Port N: text" lines back into the cannedMessages
                // array. Lines that don't match the format are kept as
                // best-effort text in their natural index order.
                let lines = newJoined.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                var msgs: [String] = Array(repeating: "", count: TextLCDBrickData.portCount)
                for (i, line) in lines.prefix(TextLCDBrickData.portCount).enumerated() {
                    // Strip "Port N: " prefix if present.
                    let trimmed: String
                    if let colon = line.firstIndex(of: ":") {
                        trimmed = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    } else {
                        trimmed = line.trimmingCharacters(in: .whitespaces)
                    }
                    msgs[i] = String(trimmed.prefix(TextLCDBrickData.charLimit))
                }
                lcd.cannedMessages = msgs
                lcd.updatedDate = Date()
            }
        )
    }

    // MARK: Note editor wiring (Michael 2026-05-20)

    /// "Edit note…" menu item used in every brick's context menu.
    /// Companion to the always-visible note.text glyph button.
    @ViewBuilder
    private func editNoteMenuItem(open: @escaping () -> Void) -> some View {
        Button {
            open()
        } label: {
            Label("Edit note…", systemImage: "note.text")
        }
    }

    private func openNoteEditorForTimer(_ timer: TimerModuleData) {
        noteEditorTarget = NoteEditorTarget(
            id: timer.id,
            title: timer.notation.isEmpty ? "Timer" : timer.notation,
            initialNote: timer.note,
            onSave: { newNote in
                timer.note = newNote
                timer.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForGate(_ gate: GateBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: gate.id,
            title: gate.gateType.displayName,
            initialNote: gate.note,
            onSave: { newNote in
                gate.note = newNote
                gate.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForSupplemental(_ sup: SupplementalBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: sup.id,
            title: sup.notation.isEmpty ? sup.brickType.displayName : sup.notation,
            initialNote: sup.note,
            onSave: { newNote in
                sup.note = newNote
                sup.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForStart(_ start: StartBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: start.id,
            title: start.notation.isEmpty ? "Trigger" : start.notation,
            initialNote: start.note,
            onSave: { newNote in
                start.note = newNote
                start.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForDelay(_ delay: DelayBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: delay.id,
            title: delay.notation.isEmpty ? "Delay" : delay.notation,
            initialNote: delay.note,
            onSave: { newNote in
                delay.note = newNote
                delay.updatedDate = Date()
            }
        )
    }

    private func openRenameEditorForDelay(_ delay: DelayBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: delay.id,
            title: "Rename Delay",
            initialNote: delay.notation,
            onSave: { newName in
                delay.notation = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                delay.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForTextLCD(_ lcd: TextLCDBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: lcd.id,
            title: lcd.notation.isEmpty ? "Text LCD" : lcd.notation,
            initialNote: lcd.note,
            onSave: { newNote in
                lcd.note = newNote
                lcd.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForGlyphLCD(_ lcd: GlyphLCDBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: lcd.id,
            title: lcd.notation.isEmpty ? "Glyph LCD" : lcd.notation,
            initialNote: lcd.note,
            onSave: { newNote in
                lcd.note = newNote
                lcd.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForDigitalClock(_ clock: DigitalClockBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: clock.id,
            title: clock.notation.isEmpty ? "Clock" : clock.notation,
            initialNote: clock.note,
            onSave: { newNote in
                clock.note = newNote
                clock.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForCalendarDate(_ cd: CalendarDateBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: cd.id,
            title: cd.notation.isEmpty ? "Date" : cd.notation,
            initialNote: cd.note,
            onSave: { newNote in
                cd.note = newNote
                cd.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForBattery(_ b: BatteryBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: b.id,
            title: b.notation.isEmpty ? "Battery" : b.notation,
            initialNote: b.note,
            onSave: { newNote in
                b.note = newNote
                b.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForWeather(_ w: WeatherBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: w.id,
            title: w.notation.isEmpty ? "Weather" : w.notation,
            initialNote: w.note,
            onSave: { newNote in
                w.note = newNote
                w.updatedDate = Date()
            }
        )
    }

    private func openNoteEditorForNoteModule(_ note: NoteModuleBrickData) {
        noteEditorTarget = NoteEditorTarget(
            id: note.id,
            title: note.notation.isEmpty ? "Note" : note.notation,
            initialNote: note.note,
            onSave: { newNote in
                note.note = newNote
                note.updatedDate = Date()
            }
        )
    }

    /// Right-click / long-press context menu items for a card.
    /// Includes Move Up/Down/Left/Right + Delete (Michael caught
    /// both the missing delete and missing move 2026-05-19).
    @ViewBuilder
    private func deleteMenuItem(for brick: CanvasBrick) -> some View {
        Button {
            move(brick, by: (-1, 0))  // row up
        } label: {
            Label("Move up a row", systemImage: "arrow.up")
        }
        Button {
            move(brick, by: (1, 0))   // row down
        } label: {
            Label("Move down a row", systemImage: "arrow.down")
        }
        Button {
            move(brick, by: (0, -1))  // column left
        } label: {
            Label("Move left a column", systemImage: "arrow.left")
        }
        Button {
            move(brick, by: (0, 1))   // column right
        } label: {
            Label("Move right a column", systemImage: "arrow.right")
        }
        Divider()
        Button(role: .destructive) {
            deleteCanvasBrick(brick)
        } label: {
            Label("Delete card", systemImage: "trash")
        }
    }

    /// Polymorphic move — adjusts a card's `order` (row) and
    /// `column` by the given delta. Bottom-clamped to 0 so cards
    /// can't move to negative positions.
    private func move(_ brick: CanvasBrick, by delta: (row: Int, column: Int)) {
        switch brick {
        case .timer(let t):
            t.order = max(0, t.order + delta.row)
            t.column = max(0, t.column + delta.column)
            t.updatedDate = Date()
        case .gate(let g):
            g.order = max(0, g.order + delta.row)
            g.column = max(0, g.column + delta.column)
            g.updatedDate = Date()
        case .supplemental(let s):
            s.order = max(0, s.order + delta.row)
            s.column = max(0, s.column + delta.column)
            s.updatedDate = Date()
        case .start(let st):
            st.order = max(0, st.order + delta.row)
            st.column = max(0, st.column + delta.column)
            st.updatedDate = Date()
        case .delay(let d):
            d.order = max(0, d.order + delta.row)
            d.column = max(0, d.column + delta.column)
            d.updatedDate = Date()
        case .textLCD(let l):
            l.order = max(0, l.order + delta.row)
            l.column = max(0, l.column + delta.column)
            l.updatedDate = Date()
        case .glyphLCD(let gl):
            gl.order = max(0, gl.order + delta.row)
            gl.column = max(0, gl.column + delta.column)
            gl.updatedDate = Date()
        case .digitalClock(let dc):
            dc.order = max(0, dc.order + delta.row)
            dc.column = max(0, dc.column + delta.column)
            dc.updatedDate = Date()
        case .calendarDate(let cd):
            cd.order = max(0, cd.order + delta.row)
            cd.column = max(0, cd.column + delta.column)
            cd.updatedDate = Date()
        case .battery(let b):
            b.order = max(0, b.order + delta.row)
            b.column = max(0, b.column + delta.column)
            b.updatedDate = Date()
        case .noteModule(let n):
            n.order = max(0, n.order + delta.row)
            n.column = max(0, n.column + delta.column)
            n.updatedDate = Date()
        case .weather(let w):
            w.order = max(0, w.order + delta.row)
            w.column = max(0, w.column + delta.column)
            w.updatedDate = Date()
        case .cpm(let c):
            c.order = max(0, c.order + delta.row)
            c.column = max(0, c.column + delta.column)
            c.updatedDate = Date()
        }
    }

    /// Polymorphic delete across all brick families.
    private func deleteCanvasBrick(_ brick: CanvasBrick) {
        switch brick {
        case .timer(let t):          modelContext.delete(t)
        case .gate(let g):           modelContext.delete(g)
        case .supplemental(let s):   modelContext.delete(s)
        case .start(let st):         modelContext.delete(st)
        case .delay(let d):          modelContext.delete(d)
        case .textLCD(let l):        modelContext.delete(l)
        case .glyphLCD(let gl):      modelContext.delete(gl)
        case .digitalClock(let dc):  modelContext.delete(dc)
        case .calendarDate(let cd):  modelContext.delete(cd)
        case .battery(let b):        modelContext.delete(b)
        case .noteModule(let n):     modelContext.delete(n)
        case .weather(let w):        modelContext.delete(w)
        case .cpm(let c):            modelContext.delete(c)
        }
    }

    /// Called when a brick is tapped while the canvas is in wiring
    /// mode. Drives the tap-to-wire state machine: first tap picks
    /// the source, second tap creates the wire to that destination.
    private func tappedBrick(_ brickId: UUID) {
        guard wiring.isWiring else { return }
        switch wiring.mode {
        case .idle:
            return
        case .awaitingSource:
            wiring.pickedSource(brickId)
        case .awaitingDestination:
            if let sourceId = wiring.pickedDestination(brickId) {
                createWire(from: sourceId, to: brickId)
            }
        }
    }

    /// Create a TraceData connecting the two bricks via the
    /// tap-to-wire flow. Default to FS (Finish → Start) with no
    /// lag; the user adjusts via the trace's popover (future).
    private func createWire(from sourceId: UUID, to destId: UUID) {
        let new = TraceData(
            traceType: .fsEdge,
            sourceBrickId: sourceId,
            destinationBrickIds: [destId],
            lagSeconds: 0,
            order: 0,
            column: 0,
            ganttChartId: chartId,
            notation: ""
        )
        modelContext.insert(new)
    }

    /// Right-side drop zone within a row — tap to pick a card type
    /// from a menu, or drag onto it to drop a card. Either way the
    /// new card is added at the next column position in this row.
    private func addToRowDropZone(_ rowIndex: Int) -> some View {
        let isTargeted = (dropTargetedRow == rowIndex)
        return Menu {
            cardPickerMenu(row: rowIndex, column: nextColumn(for: rowIndex))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])
                    )
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                    Text(isTargeted ? "Add to row" : "Add module")
                        .font(.caption2)
                }
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            }
            .frame(width: 100, height: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: BrickType.self) { items, _ in
            handleDrop(items, targetRow: rowIndex, targetColumn: nextColumn(for: rowIndex))
        } isTargeted: { targeted in
            dropTargetedRow = targeted ? rowIndex : (dropTargetedRow == rowIndex ? nil : dropTargetedRow)
        }
    }

    /// Menu of card types that mirrors the palette grouping. Tapping
    /// a row inserts that card at the given row + column position.
    @ViewBuilder
    private func cardPickerMenu(row: Int, column: Int) -> some View {
        Section("Functional") {
            Button("Timer") { addCard(.timerModule, row: row, column: column) }
        }
        Section("Logic gates") {
            Button("AND")  { addCard(.andGate,  row: row, column: column) }
            Button("OR")   { addCard(.orGate,   row: row, column: column) }
            Button("NOT")  { addCard(.notGate,  row: row, column: column) }
            Button("NOR")  { addCard(.norGate,  row: row, column: column) }
            Button("NAND") { addCard(.nandGate, row: row, column: column) }
            Button("XOR")  { addCard(.xorGate,  row: row, column: column) }
            Button("XNOR") { addCard(.xnorGate, row: row, column: column) }
        }
        Section("Supplemental") {
            Button("Note")       { addCard(.note,        row: row, column: column) }
            Button("Marker")     { addCard(.marker,      row: row, column: column) }
            Button("Trigger")    { addCard(.trigger,     row: row, column: column) }
            Button("Action")     { addCard(.action,      row: row, column: column) }
            Button("Group")      { addCard(.group,       row: row, column: column) }
            Button("Variable")   { addCard(.variable,    row: row, column: column) }
            Button("Webhook")    { addCard(.webhook,     row: row, column: column) }
            Button("Conditional"){ addCard(.conditional, row: row, column: column) }
            Button("Loop")       { addCard(.loop,        row: row, column: column) }
            Button("End")        { addCard(.endBrick,    row: row, column: column) }
        }
    }

    /// Tap-to-add bridge — delegates to handleDrop using a
    /// single-element items array.
    private func addCard(_ type: BrickType, row: Int, column: Int) {
        _ = handleDrop([type], targetRow: row, targetColumn: column)
    }

    // MARK: Add-new-row drop zone

    private var addNewRowDropZone: some View {
        Menu {
            cardPickerMenu(row: nextAvailableRow(), column: 0)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        dropTargetedNewRow ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )
                HStack(spacing: 8) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                    Text(dropTargetedNewRow ? "Release to add a new row" : "Tap to add a card to a new row")
                        .font(.subheadline)
                }
                .foregroundStyle(dropTargetedNewRow ? Color.accentColor : .secondary)
            }
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: BrickType.self) { items, _ in
            handleDrop(items, targetRow: nextAvailableRow(), targetColumn: 0)
        } isTargeted: { targeted in
            dropTargetedNewRow = targeted
        }
    }

    // MARK: Trace edge overlay

    @ViewBuilder
    private var traceEdgeOverlay: some View {
        // Each trace gets its own color, auto-assigned by creation
        // order. First trace is red (hue 0°); subsequent traces step
        // around the color wheel by 360°/paletteSize so each is
        // visually distinct from its neighbors (Michael 2026-05-20:
        // "the color wheel approach"). User-pickable colors are
        // deferred to a future upgrade.
        let wiredTracesByCreation = traces
            .filter { $0.isWired }
            .sorted { $0.createdDate < $1.createdDate }
        let traceColorById: [UUID: Color] = Dictionary(
            uniqueKeysWithValues: wiredTracesByCreation.enumerated().map { idx, t in
                (t.id, Self.colorWheelColor(for: idx))
            }
        )

        return Canvas { ctx, size in
            for trace in wiredTracesByCreation {
                guard let srcId = trace.sourceBrickId,
                      let srcFrame = brickFrames[srcId] else { continue }
                let srcPoint = anchorPoint(of: srcFrame, side: trace.sourceAnchor)
                let color = traceColorById[trace.id] ?? .blue

                for destId in trace.destinationBrickIds {
                    guard let destFrame = brickFrames[destId] else { continue }
                    let destPoint = anchorPoint(of: destFrame, side: trace.destinationAnchor)
                    drawArrow(
                        in: ctx,
                        from: srcPoint,
                        to: destPoint,
                        srcFrame: srcFrame,
                        destFrame: destFrame,
                        color: color
                    )
                }
            }
        }
    }

    /// Golden-angle hue rotation — each consecutive trace lands far
    /// across the color wheel from the previous one so adjacent
    /// traces never read as the same color family (Michael 2026-05-20:
    /// "the colors from the color wheel could be opposites chosen so
    /// they dont look to similar"). The first trace is red at hue 0;
    /// subsequent traces step by the golden angle (137.508°)
    /// normalized to a 0...1 fraction, producing a distribution that
    /// maximizes color separation for any number of traces.
    private static let goldenAngleHueStep: Double = 0.38196601125010515

    private static func colorWheelColor(for index: Int) -> Color {
        let hue = (Double(index) * goldenAngleHueStep).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }

    /// Tappable × button positioned at each wired trace's lane
    /// midpoint so the user can delete an unwanted trace. Sits in a
    /// separate hit-testing overlay because the Canvas { } that
    /// renders the trace path has hit testing disabled.
    /// (Michael 2026-05-20: "i cant select a trace to delete it.")
    @ViewBuilder
    private var traceDeleteHandles: some View {
        ZStack(alignment: .topLeading) {
            ForEach(deconflictedHandles, id: \.traceId) { handle in
                Button {
                    deleteTrace(handle.trace)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.4))
                                .frame(width: 22, height: 22)
                        )
                        .frame(width: 28, height: 28)
                        // Circle hit shape so taps only count when
                        // they're on the visible ×, not on the
                        // 28×28 bounding box's empty corners — keeps
                        // a neighbor module's note glyph from
                        // catching taps meant for the × (Michael
                        // 2026-05-20).
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Delete this trace")
                .position(x: handle.position.x, y: handle.position.y)
            }
        }
        // Win the layer race against per-card overlays (e.g. note
        // glyph buttons) so the × button is always on top when the
        // positions happen to coincide.
        .zIndex(10)
        .allowsHitTesting(true)
    }

    /// Position + trace pair after running deconfliction so two ×
    /// markers landing on nearly-identical coordinates get nudged
    /// apart vertically (Michael 2026-05-20 — preemptive). The first
    /// of any colliding pair keeps its computed Y; the others shift
    /// by ±18pt alternately so the pair is two distinct tappable
    /// targets even before pinch-zoom magnification.
    private var deconflictedHandles: [TraceHandle] {
        let raw = traces
            .filter { $0.isWired }
            .compactMap { trace -> TraceHandle? in
                guard let pos = traceMidpoint(trace) else { return nil }
                return TraceHandle(traceId: trace.id, trace: trace, position: pos)
            }
        var placed: [TraceHandle] = []
        let collisionRadius: CGFloat = 22
        for var candidate in raw {
            var attempt = 0
            while placed.contains(where: { hypot($0.position.x - candidate.position.x,
                                                 $0.position.y - candidate.position.y) < collisionRadius }) {
                attempt += 1
                let dy: CGFloat = (attempt % 2 == 1 ? 1 : -1) * 18 * CGFloat((attempt + 1) / 2)
                candidate = TraceHandle(
                    traceId: candidate.traceId,
                    trace: candidate.trace,
                    position: CGPoint(x: candidate.position.x, y: candidate.position.y + dy)
                )
                if attempt > 6 { break }
            }
            placed.append(candidate)
        }
        return placed
    }

    private struct TraceHandle {
        let traceId: UUID
        let trace: TraceData
        let position: CGPoint
    }

    /// Returns the on-trace midpoint position for a × delete handle.
    ///
    /// For **adjacent same-row** traces (source and destination at
    /// roughly the same midY and their X edges essentially touching
    /// across the inter-card gap) the wire is drawn as a straight
    /// short segment in the gap; the × sits on that segment at the
    /// average of the two attachment Y values (Michael 2026-05-20).
    ///
    /// For all other traces (cross-row, or same-row with intervening
    /// cards) the wire takes the lane-below detour and the × sits at
    /// the midpoint of the lane segment.
    private func traceMidpoint(_ trace: TraceData) -> CGPoint? {
        guard let srcId = trace.sourceBrickId,
              let srcFrame = brickFrames[srcId],
              let destId = trace.destinationBrickIds.first,
              let destFrame = brickFrames[destId] else { return nil }
        let srcPoint = anchorPoint(of: srcFrame, side: trace.sourceAnchor)
        let destPoint = anchorPoint(of: destFrame, side: trace.destinationAnchor)

        if isAdjacentSameRow(srcFrame: srcFrame, destFrame: destFrame) {
            return CGPoint(
                x: (srcPoint.x + destPoint.x) / 2,
                y: (srcPoint.y + destPoint.y) / 2
            )
        }

        let laneGap: CGFloat = 18
        let lane = max(srcFrame.maxY, destFrame.maxY) + laneGap
        return CGPoint(
            x: (srcPoint.x + destPoint.x) / 2,
            y: lane
        )
    }

    /// True when source and destination sit on the same row at
    /// matching midY and their adjacent edges are within one inter-
    /// card gap. Used by both the × placement helper and drawArrow
    /// so the wire and its handle stay in sync.
    private func isAdjacentSameRow(srcFrame: CGRect, destFrame: CGRect) -> Bool {
        let sameRow = abs(srcFrame.midY - destFrame.midY) < 6
        let leftToRight = srcFrame.maxX <= destFrame.minX
        let rightToLeft = destFrame.maxX <= srcFrame.minX
        guard sameRow, leftToRight || rightToLeft else { return false }
        let horizontalGap = leftToRight
            ? destFrame.minX - srcFrame.maxX
            : srcFrame.minX - destFrame.maxX
        // Row HStack spacing is 10pt — anything ≤ 24pt apart is
        // visually "right next to each other" for the user.
        return horizontalGap <= 24
    }

    private func deleteTrace(_ trace: TraceData) {
        modelContext.delete(trace)
        try? modelContext.save()
    }

    private func anchorPoint(of frame: CGRect, side: TraceAnchor) -> CGPoint {
        switch side {
        case .start:  return CGPoint(x: frame.minX, y: frame.midY)
        case .finish: return CGPoint(x: frame.maxX, y: frame.midY)
        }
    }

    private func drawArrow(
        in ctx: GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        srcFrame: CGRect,
        destFrame: CGRect,
        color: Color
    ) {
        // Orthogonal lane-below routing with horizontal stubs at both
        // endpoints (Michael 2026-05-20: "the trace is covering a
        // module"). Previous version put the lane at max(srcMid,
        // destMid) + 24 which fell INSIDE the card body, and entered
        // the destination's left-edge midpoint vertically — both
        // caused the wire to cross card faces.
        //
        // The new path: exits the source's right edge with a short
        // horizontal stub, drops to a lane below BOTH card bottoms,
        // crosses to the destination's column, and approaches the
        // destination from the left with another horizontal stub. The
        // wire never enters any card body.
        // Adjacent same-row shortcut: source and destination are
        // right next to each other in the same row, so the wire is
        // just a short straight segment in the inter-card gap — no
        // need to detour down to a lane and back up. (Michael
        // 2026-05-20: "pomerado work and pomerado break
        // connecterpoints are right next to each other so i should
        // only see a red x and no green trace.")
        if isAdjacentSameRow(srcFrame: srcFrame, destFrame: destFrame) {
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            ctx.stroke(
                path,
                with: .color(color.opacity(0.85)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            // Arrowhead at the destination pointing in along the
            // segment direction.
            let theta: CGFloat = .pi / 7
            let headLength: CGFloat = 10
            let angle = atan2(end.y - start.y, end.x - start.x)
            let h1 = CGPoint(
                x: end.x - headLength * cos(angle - theta),
                y: end.y - headLength * sin(angle - theta)
            )
            let h2 = CGPoint(
                x: end.x - headLength * cos(angle + theta),
                y: end.y - headLength * sin(angle + theta)
            )
            var head = Path()
            head.move(to: end); head.addLine(to: h1)
            head.move(to: end); head.addLine(to: h2)
            ctx.stroke(
                head,
                with: .color(color.opacity(0.85)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            return
        }

        // Stub width must stay smaller than the inter-card spacing
        // (HStack spacing: 10 on the row) so the vertical drop lands
        // INSIDE the gap between cards rather than ON the next card's
        // edge. Michael 2026-05-20 — "traces can overlap each other,
        // they just shouldnt go over a module."
        let stubGap: CGFloat = 4
        let laneGap: CGFloat = 18
        let lane = max(srcFrame.maxY, destFrame.maxY) + laneGap

        let srcStub  = CGPoint(x: start.x + stubGap, y: start.y)
        let destStub = CGPoint(x: end.x   - stubGap, y: end.y)

        var path = Path()
        path.move(to: start)
        path.addLine(to: srcStub)
        path.addLine(to: CGPoint(x: srcStub.x,  y: lane))
        path.addLine(to: CGPoint(x: destStub.x, y: lane))
        path.addLine(to: destStub)
        path.addLine(to: end)
        ctx.stroke(
            path,
            with: .color(color.opacity(0.85)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )

        // Arrowhead at the destination. The final approach segment is
        // horizontal (destStub → end), so the head points right.
        let theta: CGFloat = .pi / 7
        let headLength: CGFloat = 10
        let angle = atan2(end.y - destStub.y, end.x - destStub.x)
        let h1 = CGPoint(
            x: end.x - headLength * cos(angle - theta),
            y: end.y - headLength * sin(angle - theta)
        )
        let h2 = CGPoint(
            x: end.x - headLength * cos(angle + theta),
            y: end.y - headLength * sin(angle + theta)
        )
        var head = Path()
        head.move(to: end); head.addLine(to: h1)
        head.move(to: end); head.addLine(to: h2)
        ctx.stroke(head, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    // MARK: Drop handling

    private func handleDrop(_ items: [BrickType], targetRow: Int, targetColumn: Int) -> Bool {
        guard let type = items.first else { return false }
        guard type.isWiredUp else { return false }

        let row = targetRow
        let column = targetColumn

        switch type {
        case .timerModule:
            let new = TimerModuleData(
                notation: "Timer \(row + 1).\(column + 1)",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .calendarProcessing:
            // 4×4 Calendar Processing Module — spec lives in
            // TimerModules-Brain-Module-Refinement-2026-05-22.html.
            // Phase 1 scaffold: create the brick with default empty
            // event list. Smart Stack faces, EventKit hookup, and
            // dedicated TimerModulesCPM calendar arrive in later phases.
            let new = CPMBrickData(
                notation: "CPM",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .start:
            // Locked design (Part I § 2): exactly ONE Trigger per chart
            // for v1.0. (May relax for multi-Trigger cascades per the
            // 2026-05-21 R&D session — deferred to shakedown.)
            let existingStart = starts.first { $0.ganttChartId == chartId }
            guard existingStart == nil else { return false }
            let new = StartBrickData(
                notation: "Trigger",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .delay:
            // 1×1 Delay module (Master Design Spec 18.4). Default
            // displayValue = 5 (held seconds = 6). User adjusts via
            // the long-press / right-click context menu.
            let new = DelayBrickData(
                notation: "Delay",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .textLCD:
            // 4×1 Text LCD module (Master Design Spec 19). Ships
            // with empty canned-message slots; user edits via context
            // menu's "Edit canned messages…".
            let new = TextLCDBrickData(
                notation: "Text LCD",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .glyphLCD:
            // 1×4 Glyph LCD module (Master Design Spec 19). Default
            // glyphs are common SF Symbols; user edits via "Edit glyphs…".
            let new = GlyphLCDBrickData(
                notation: "Glyph LCD",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .digitalClock:
            // 2×1 passive Digital Clock module (Master Design Spec 12).
            // Shows current system time. Defaults to 12-hour AM/PM
            // (toggle via long-press / right-click).
            let new = DigitalClockBrickData(
                notation: "Clock",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .calendarDate:
            // 2×1 passive Calendar Date module (Master Design Spec
            // 12.10). Shows current system date. Defaults to
            // "May 21 Thu" format.
            let new = CalendarDateBrickData(
                notation: "Date",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .battery:
            // 1×1 passive Battery module (Master Design Spec 12.11).
            // Battery % on iOS/iPad; "AC" on Mac per the v1.0 shim.
            let new = BatteryBrickData(
                notation: "Battery",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .noteModule:
            // 4×4 Note module with Smart Stack of swipable pages
            // (Master Design Spec 22.7). Starts with one blank page;
            // user adds more via context menu.
            let new = NoteModuleBrickData(
                notation: "Note",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .weather:
            // 2×1 Weather module (Master Design Spec 12.12). Defaults
            // to Surfside Beach, TX per Michael's bio file; user
            // edits via context menu (post-shakedown).
            let new = WeatherBrickData(
                notation: "Weather",
                order: row,
                column: column,
                ganttChartId: chartId
            )
            modelContext.insert(new)
            return true

        case .andGate, .orGate, .notGate, .norGate,
             .nandGate, .xorGate, .xnorGate:
            let new = GateBrickData(
                gateType: type,
                order: row,
                column: column,
                ganttChartId: chartId,
                notation: ""
            )
            modelContext.insert(new)
            return true

        case .trace:
            // M5.7: traces are now created via tap-to-wire, not by
            // dragging the palette tile onto the canvas. The Trace
            // tile uses .onTapGesture (no .draggable) so this case
            // shouldn't be hit — but guard defensively.
            return false

        case .fsEdge, .ssEdge, .ffEdge, .sfEdge, .lagLead, .splitter:
            return false  // not palette tiles

        case .note, .marker, .trigger, .action,
             .group, .variable, .webhook,
             .conditional, .loop, .endBrick:
            let new = SupplementalBrickData(
                brickType: type,
                order: row,
                column: column,
                ganttChartId: chartId,
                notation: ""
            )
            modelContext.insert(new)
            return true
        }
    }

    /// Next row index after the highest existing row in this chart.
    private func nextAvailableRow() -> Int {
        let maxRow = allBricks.map(\.row).max() ?? -1
        return maxRow + 1
    }

    /// Next column index after the highest existing column in the
    /// given row in this chart.
    private func nextColumn(for row: Int) -> Int {
        let inRow = allBricks.filter { $0.row == row }
        let maxCol = inRow.map(\.column).max() ?? -1
        return maxCol + 1
    }
}
