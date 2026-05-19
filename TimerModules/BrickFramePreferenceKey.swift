// MARK: - BrickFramePreferenceKey
//
// SwiftUI PreferenceKey for tracking each brick's frame on the
// Gantt canvas. Bricks emit their frame via a GeometryReader
// background; the canvas captures all frames and uses them to
// draw trace edges (M4 overlay).

import SwiftUI

struct BrickFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Attach to a brick view to report its frame (in the
    /// "canvas" coordinate space) up to the GanttCanvasView so
    /// trace edges can be drawn between brick positions.
    func reportBrickFrame(id: UUID) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: BrickFramePreferenceKey.self,
                    value: [id: geo.frame(in: .named("ganttCanvas"))]
                )
            }
        )
    }
}
