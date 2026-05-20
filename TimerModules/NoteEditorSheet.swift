// MARK: - NoteEditorSheet
//
// Modal sheet (iPhone) / popover-style sheet (iPad/Mac) for
// editing a module's free-form note (Michael 2026-05-20). Used
// by Timer, Gate, and Supplemental cards. Same editor everywhere;
// the parent passes the module's title and a binding-style save
// callback.

import SwiftUI

struct NoteEditorSheet: View {
    /// Display title shown at the top of the sheet so the user knows
    /// which module's note they're editing.
    let title: String

    /// The current note text. The sheet edits a local @State draft so
    /// the user can Cancel without persisting.
    let initialNote: String

    /// Invoked with the new note text when the user taps Save.
    /// The parent persists it on the module's data model and writes
    /// a LogEntry so the note shows up in the LogView.
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft)
                    .font(.system(size: 16))
                    .padding(12)

                if draft.isEmpty {
                    Text("Type your note for this module…")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear { draft = initialNote }
        .frame(minWidth: 420, minHeight: 320)
    }
}

#Preview {
    NoteEditorSheet(
        title: "Timer 1.1",
        initialNote: "",
        onSave: { _ in }
    )
}
