// MARK: - ZoomableCanvas
//
// SwiftUI wrapper around the platform-native scrollable+zoomable
// container (UIScrollView on iOS/iPadOS, NSScrollView on macOS).
// Replaces the SwiftUI ScrollView + .scaleEffect pinch hack which
// couldn't reconcile zoom with content bounds — pan stopped reaching
// the corners of zoomed content (Michael 2026-05-20).
//
// UX target: Apple Freeform — infinite-paper feel with smooth pinch
// zoom (0.5x – 4x), pan in any direction, content bounds growing
// with zoom so the user can reach every corner of the zoomed view.
//
// Trade-off shipping with v1.0: the previous SwiftUI
// `ScrollViewReader.scrollTo(...)` auto-scroll-to-active-row feature
// doesn't apply here — it's a SwiftUI-ScrollView-only mechanism.
// Follow-up will add a programmatic scroll API on this view if the
// auto-scroll is missed.

import SwiftUI

#if canImport(UIKit)
import UIKit

struct ZoomableCanvas<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .clear
        // Honor the safe area so row 0 doesn't get clamped under the
        // app's top toolbar. With `.never` the scroll view's natural
        // rest position lets content sit under the chrome and the
        // bounce-back snaps it right back when the user pulls down.
        scrollView.contentInsetAdjustmentBehavior = .always

        let hosting = UIHostingController(rootView: content())
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        ])

        context.coordinator.hostingController = hosting
        context.coordinator.hostedView = hosting.view
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // SwiftUI invalidates this representable when @State above
        // changes; push the latest content down to the hosted view.
        context.coordinator.hostingController?.rootView = content()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        weak var hostedView: UIView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostedView
        }
    }
}

#elseif os(macOS)
import AppKit

struct ZoomableCanvas<Content: View>: NSViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.5
        scrollView.maxMagnification = 4.0
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let hosting = NSHostingController(rootView: content())
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: documentView.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])

        scrollView.documentView = documentView
        context.coordinator.hostingController = hosting
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content()
    }

    final class Coordinator: NSObject {
        var hostingController: NSHostingController<Content>?
    }
}

#endif
