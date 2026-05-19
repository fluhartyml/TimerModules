import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Image-first detail view for media-typed records inside Vault > Media.
/// Replaces the universal RecordDetailView for this sub-module so the user
/// sees the IMAGE rather than a metadata form with the image buried in an
/// Attachments section. Metadata stays accessible via a secondary panel.
struct MediaDetailView: View {
    let id: UUID
    let store: OperatorStore

    @State private var showingMetadata: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var item: OperatorItem? {
        store.item(id: id)
    }

    private var imageAttachment: Attachment? {
        item?.attachments?.first(where: { $0.kind == .image })
    }

    var body: some View {
        Group {
            if let item {
                content(for: item)
            } else {
                ContentUnavailableView("Record Removed", systemImage: "trash")
            }
        }
        .navigationTitle(item?.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let item {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingMetadata = true
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: shareText(for: item), preview: SharePreview(item.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingMetadata) {
            if let item {
                MediaMetadataSheet(item: item)
            }
        }
    }

    @ViewBuilder
    private func content(for item: OperatorItem) -> some View {
        if let attachment = imageAttachment, let image = loadImage(for: attachment) {
            ZoomableImageContainer(image: image, title: item.title)
        } else {
            ContentUnavailableView {
                Label("No Image", systemImage: "photo")
            } description: {
                Text("This media record has no image attachment yet. Open it in the standard record view to add one.")
            }
        }
    }

    private func loadImage(for attachment: Attachment) -> PlatformImage? {
        let url = AttachmentStorage.url(for: attachment.filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return PlatformImage(data: data)
    }

    private func shareText(for item: OperatorItem) -> String {
        "\(item.title)\nShared from OPerationsHOS · Vault Media"
    }
}

/// Cross-platform image type alias so the view compiles for both iOS and macOS.
#if canImport(UIKit)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
#endif

private struct ZoomableImageContainer: View {
    let image: PlatformImage
    let title: String

    @State private var currentScale: CGFloat = 1.0
    @State private var liveScale: CGFloat = 1.0

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 6.0

    private var effectiveScale: CGFloat {
        max(minScale, min(maxScale, currentScale * liveScale))
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            imageView
                .scaleEffect(effectiveScale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            liveScale = value.magnification
                        }
                        .onEnded { value in
                            currentScale = max(minScale, min(maxScale, currentScale * value.magnification))
                            liveScale = 1.0
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        currentScale = currentScale > 1.0 ? 1.0 : 2.0
                    }
                }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var imageView: some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(title)
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(title)
        #endif
    }
}

private struct MediaMetadataSheet: View {
    let item: OperatorItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !item.subtitle.isEmpty {
                    Section("Subtitle") { Text(item.subtitle) }
                }
                if !item.body.isEmpty {
                    Section("Notes") { Text(item.body) }
                }
                Section("Metadata") {
                    LabeledContent("Type", value: item.type.label)
                    LabeledContent("Status", value: item.status.label)
                    LabeledContent("Created", value: item.createdDate.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Updated", value: item.updatedDate.formatted(date: .abbreviated, time: .shortened))
                }
                if !item.tags.isEmpty {
                    Section("Tags") {
                        Text(item.tags.joined(separator: ", "))
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(item.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
