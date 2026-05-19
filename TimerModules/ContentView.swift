import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            BrickPaletteView()
                .frame(maxHeight: 180)

            Divider()

            GanttCanvasView()
        }
    }
}
