// MARK: - NoteModuleBrickView
//
// 4×4 large-widget canvas annotation with a Smart Stack of swipable
// pages. Master Design Spec Part II §22.7.
//
// Uses a vertical paging TabView for the page-swipe gesture (matching
// Apple's Smart Stack convention per 14.2). Custom dot column on the
// left edge (per 14.6 — left edge for vertical swipes). Page edit via
// long-press / right-click → context menu → modal sheet.

import SwiftUI
import SwiftData

struct NoteModuleBrickView: View {
    @Bindable var data: NoteModuleBrickData

    var onEditNoteTapped: () -> Void = {}
    var onPageEditTapped: (Int) -> Void = { _ in }
    var onLastPageReached: () -> Void = {}

    private let cellSize: CGFloat = 60
    private var width:  CGFloat { cellSize * 4 }
    private var height: CGFloat { cellSize * 4 }

    /// SwiftUI Binding wired into TabView's selection.
    private var pageBinding: Binding<Int> {
        Binding(
            get: { data.currentPageIndex },
            set: { newIndex in
                let clamped = max(0, min(data.pages.count - 1, newIndex))
                data.currentPageIndex = clamped
                data.updatedDate = Date()
                if clamped == data.pages.count - 1 {
                    onLastPageReached()
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 4) {
                // Left-edge dot column (per Master Design Spec 14.6).
                pageDotsColumn

                // Vertical paging through the Smart Stack of pages.
                TabView(selection: pageBinding) {
                    ForEach(0..<data.pages.count, id: \.self) { index in
                        pageView(index: index, content: data.pages[index])
                            .tag(index)
                    }
                }
                #if !os(macOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(6)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
            )

            // Note-glyph in top-right corner.
            Button {
                onEditNoteTapped()
            } label: {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundStyle(data.note.isEmpty ? Color.secondary.opacity(0.4) : Color.cyan)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(data.note.isEmpty ? "Add note" : "Edit note")
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note module, page \(data.currentPageIndex + 1) of \(data.pages.count)")
    }

    // MARK: - Subviews

    /// Left-edge column of dots indicating which page is active.
    /// Matches Apple's Smart Stack convention (14.6 — vertical swipes
    /// use left-edge dots; horizontal page swipes use bottom dots).
    private var pageDotsColumn: some View {
        VStack(spacing: 6) {
            ForEach(0..<data.pages.count, id: \.self) { i in
                Circle()
                    .fill(i == data.currentPageIndex ? Color.cyan : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 8)
    }

    /// One page of the Smart Stack. Tap → no-op (reading mode);
    /// long-press → context menu via the parent's onPageEditTapped.
    @ViewBuilder
    private func pageView(index: Int, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Page \(index + 1)/\(data.pages.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ScrollView {
                Text(content.isEmpty ? "(empty page — long-press to edit)" : content)
                    .font(.system(size: 13))
                    .foregroundStyle(content.isEmpty ? Color.secondary.opacity(0.6) : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.45))
        )
        .contextMenu {
            Button("Edit this page…") {
                onPageEditTapped(index)
            }
        }
    }
}
