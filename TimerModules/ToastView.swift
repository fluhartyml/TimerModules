import SwiftUI

/// Brief bottom-anchored confirmation banner with an Undo affordance.
/// Used to confirm reversible state changes (secure-toggle, archive, etc.) so the user
/// can see what happened and back out before the record visually moves out of view.
/// Auto-dismisses 5 seconds after each new toast (re-keyed via `.task(id:)`).

struct ToastInfo: Identifiable {
    let id = UUID()
    let message: String
    let undoAction: () -> Void
}

struct ToastView: View {
    let info: ToastInfo
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(info.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button("Undo") {
                info.undoAction()
                onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: info.id) {
            try? await Task.sleep(for: .seconds(5))
            onDismiss()
        }
    }
}

extension View {
    /// Attaches a bottom-anchored toast banner. Pass a binding to an optional ToastInfo;
    /// set it to a new value to show / replace the toast; nil to dismiss immediately.
    func toast(_ info: Binding<ToastInfo?>) -> some View {
        self.overlay(alignment: .bottom) {
            if let toast = info.wrappedValue {
                ToastView(info: toast) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        info.wrappedValue = nil
                    }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: info.wrappedValue?.id)
    }
}
