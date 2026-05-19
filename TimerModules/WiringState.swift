// MARK: - WiringState
//
// Shared state coordinating the tap-to-wire interaction between
// the BrickPaletteView (where the Trace tile is tapped) and the
// GanttCanvasView (where source + destination bricks are tapped).
//
// Lifted to GanttChartContainerView so palette and canvas are
// siblings sharing one Bindable instance.
//
// Per Michael 2026-05-19 (M5.7 design conversation):
//   "you press the trace module from the available modules,
//    the app tells the user to tap the first module to wire
//    then they tap and the app tells the user to connect to
//    the next module"

import Foundation
import SwiftUI

@Observable
final class WiringState {
    /// What stage of the tap-to-wire interaction we're in.
    enum Mode: Equatable {
        /// Default. No wiring in progress.
        case idle
        /// Trace tile was tapped; waiting for the user to tap a brick
        /// to designate as the wire's source.
        case awaitingSource
        /// Source picked; waiting for the user to tap a brick to
        /// designate as the destination. The source brick's id is
        /// stored so the canvas can highlight it and so we know which
        /// brick to wire FROM when the destination is picked.
        case awaitingDestination(sourceBrickId: UUID)
    }

    var mode: Mode = .idle

    /// True while a wire is being created (banner visible, bricks
    /// tappable for selection, palette dimmed except Trace tile).
    var isWiring: Bool {
        mode != .idle
    }

    /// The brick id currently highlighted as the source, if any.
    var highlightedSourceId: UUID? {
        if case .awaitingDestination(let id) = mode { return id }
        return nil
    }

    /// User-visible banner text for the current wiring step.
    var bannerText: String {
        switch mode {
        case .idle:                       return ""
        case .awaitingSource:             return "Tap the first module to wire"
        case .awaitingDestination:        return "Tap the next module to wire"
        }
    }

    // MARK: Transitions

    func startWiring() {
        mode = .awaitingSource
    }

    func pickedSource(_ brickId: UUID) {
        mode = .awaitingDestination(sourceBrickId: brickId)
    }

    /// Returns the source brick id if the transition completes a wire;
    /// nil if not in a state to complete one. The caller is
    /// responsible for actually creating the TraceData row.
    func pickedDestination(_ brickId: UUID) -> UUID? {
        guard case .awaitingDestination(let sourceId) = mode else { return nil }
        // Don't allow a brick to wire to itself.
        guard sourceId != brickId else { return nil }
        mode = .idle
        return sourceId
    }

    func cancel() {
        mode = .idle
    }
}

// MARK: - Wiring overlay modifier
//
// Applied to each brick view on the canvas. When the canvas is in
// wiring mode, the brick gets a thin tappable transparent overlay
// on top that captures the tap (so it doesn't pass through to the
// brick's normal controls) and routes the tap to the canvas's
// tappedBrick handler. When not wiring, the overlay is invisible
// and pass-through.
//
// Also draws a highlight ring around the currently-selected source
// brick during awaitingDestination phase.

import SwiftUI

extension View {
    func wiringOverlay(
        id: UUID,
        wiring: WiringState,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(WiringOverlayModifier(id: id, wiring: wiring, onTap: onTap))
    }
}

private struct WiringOverlayModifier: ViewModifier {
    let id: UUID
    @Bindable var wiring: WiringState
    let onTap: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if wiring.isWiring {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.accentColor.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    isHighlightedSource ? Color.accentColor : Color.accentColor.opacity(0.4),
                                    lineWidth: isHighlightedSource ? 3 : 2
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                        .onTapGesture { onTap() }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: wiring.isWiring)
            .animation(.easeInOut(duration: 0.15), value: isHighlightedSource)
    }

    private var isHighlightedSource: Bool {
        wiring.highlightedSourceId == id
    }
}
