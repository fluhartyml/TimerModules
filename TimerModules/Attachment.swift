import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID = UUID()
    var filename: String = ""
    var originalName: String = ""
    var kind: AttachmentKind = AttachmentKind.other
    var createdDate: Date = Date()
    var owner: OperatorItem?

    init(filename: String, originalName: String, kind: AttachmentKind) {
        self.id = UUID()
        self.filename = filename
        self.originalName = originalName
        self.kind = kind
        self.createdDate = Date()
    }
}

enum AttachmentKind: String, Codable, CaseIterable {
    case image
    case pdf
    case other

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.text"
        case .other: return "doc"
        }
    }

    var label: String {
        switch self {
        case .image: return "Image"
        case .pdf: return "Document"
        case .other: return "File"
        }
    }
}

enum AttachmentStorage {
    static var directoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func copy(from sourceURL: URL) throws -> (filename: String, originalName: String) {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension
        let storedName = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        let dest = directoryURL.appendingPathComponent(storedName)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return (storedName, sourceURL.lastPathComponent)
    }

    static func write(data: Data, suggestedExtension: String) throws -> (filename: String, originalName: String) {
        let storedName = "\(UUID().uuidString).\(suggestedExtension)"
        let dest = directoryURL.appendingPathComponent(storedName)
        try data.write(to: dest, options: .atomic)
        return (storedName, storedName)
    }

    static func url(for filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }

    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func kind(for url: URL) -> AttachmentKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "tif", "tiff", "webp":
            return .image
        case "pdf":
            return .pdf
        default:
            return .other
        }
    }
}
