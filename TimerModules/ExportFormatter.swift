import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case csv
    case json
    case pdf
    case zip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        case .json: return "JSON"
        case .pdf: return "PDF"
        case .zip: return "ZIP (everything)"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .csv: return "csv"
        case .json: return "json"
        case .pdf: return "pdf"
        case .zip: return "zip"
        }
    }
}

enum ExportFormatter {
    static func export(items: [OperatorItem], as format: ExportFormat) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "OPerationsHOS-\(stamp).\(format.fileExtension)"
        let url = dir.appendingPathComponent(fileName)

        switch format {
        case .markdown:
            try markdown(for: items).write(to: url, atomically: true, encoding: .utf8)
        case .csv:
            try csv(for: items).write(to: url, atomically: true, encoding: .utf8)
        case .json:
            let data = try jsonData(for: items)
            try data.write(to: url, options: .atomic)
        case .pdf:
            let data = try pdfData(for: items)
            try data.write(to: url, options: .atomic)
        case .zip:
            return try zipBundle(for: items)
        }
        return url
    }

    static func markdown(for items: [OperatorItem]) -> String {
        var out = "# OPerationsHOS Export\n\n"
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        out += "_Exported \(stamp) — \(items.count) record(s)_\n\n---\n\n"
        for item in items {
            out += "## \(item.title)\n\n"
            if !item.subtitle.isEmpty { out += "_\(item.subtitle)_\n\n" }
            out += "- Type: \(item.type.label)\n"
            out += "- Status: \(item.status.label)\n"
            out += "- Priority: \(item.priority.label)\n"
            if let due = item.dueDate {
                out += "- Due: \(due.formatted(date: .long, time: .omitted))\n"
            }
            if let system = item.relatedSystem {
                out += "- System: \(system)\n"
            }
            out += "- Created: \(item.createdDate.formatted(date: .abbreviated, time: .omitted))\n"
            out += "- Updated: \(item.updatedDate.formatted(date: .abbreviated, time: .omitted))\n"
            if !item.tags.isEmpty { out += "- Tags: \(item.tags.joined(separator: ", "))\n" }
            if item.pinned { out += "- Pinned\n" }
            if item.archived { out += "- Archived\n" }
            if !item.body.isEmpty { out += "\n\(item.body)\n" }
            out += "\n---\n\n"
        }
        return out
    }

    static func csv(for items: [OperatorItem]) -> String {
        let headers = ["Title","Subtitle","Type","Status","Priority","Due","Created","Updated","Pinned","Archived","Tags","RelatedSystem","Notes"]
        var rows: [String] = [headers.joined(separator: ",")]
        let df = ISO8601DateFormatter()
        for item in items {
            let dueString = item.dueDate.map { df.string(from: $0) } ?? ""
            let row = [
                escape(item.title),
                escape(item.subtitle),
                item.type.label,
                item.status.label,
                item.priority.label,
                dueString,
                df.string(from: item.createdDate),
                df.string(from: item.updatedDate),
                item.pinned ? "Y" : "N",
                item.archived ? "Y" : "N",
                escape(item.tags.joined(separator: "; ")),
                escape(item.relatedSystem ?? ""),
                escape(item.body)
            ]
            rows.append(row.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    static func jsonData(for items: [OperatorItem]) throws -> Data {
        let payload = items.map { item -> [String: Any?] in
            return [
                "id": item.id.uuidString,
                "title": item.title,
                "subtitle": item.subtitle,
                "body": item.body,
                "type": item.type.rawValue,
                "status": item.status.rawValue,
                "priority": item.priority.rawValue,
                "dueDate": item.dueDate.map { ISO8601DateFormatter().string(from: $0) } ?? nil,
                "createdDate": ISO8601DateFormatter().string(from: item.createdDate),
                "updatedDate": ISO8601DateFormatter().string(from: item.updatedDate),
                "tags": item.tags,
                "relatedSystem": item.relatedSystem ?? nil,
                "pinned": item.pinned,
                "archived": item.archived,
                "accumulatedSeconds": item.accumulatedSeconds,
                "linkedRecordID": item.linkedRecordID?.uuidString ?? nil
            ]
        }
        let cleaned = payload.map { dict in
            dict.compactMapValues { $0 }
        }
        return try JSONSerialization.data(withJSONObject: cleaned, options: [.prettyPrinted, .sortedKeys])
    }

    static func pdfData(for items: [OperatorItem]) throws -> Data {
        let body = markdown(for: items)
        #if canImport(UIKit)
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        let attributed = NSAttributedString(string: body, attributes: attrs)
        return renderer.pdfData { context in
            var rendered = 0
            let totalLength = attributed.length
            while rendered < totalLength {
                context.beginPage()
                let frame = CGRect(x: 36, y: 36, width: pageSize.width - 72, height: pageSize.height - 72)
                let path = CGPath(rect: frame, transform: nil)
                let framesetter = CTFramesetterCreateWithAttributedString(attributed)
                let ctFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: rendered, length: 0), path, nil)
                CTFrameDraw(ctFrame, context.cgContext)
                let visible = CTFrameGetVisibleStringRange(ctFrame)
                let consumed = visible.length
                if consumed <= 0 { break }
                rendered += consumed
            }
        }
        #else
        return body.data(using: .utf8) ?? Data()
        #endif
    }

    static func zipBundle(for items: [OperatorItem]) throws -> URL {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OPerationsHOS-Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let mdURL = workDir.appendingPathComponent("records.md")
        try markdown(for: items).write(to: mdURL, atomically: true, encoding: .utf8)
        let csvURL = workDir.appendingPathComponent("records.csv")
        try csv(for: items).write(to: csvURL, atomically: true, encoding: .utf8)
        let jsonURL = workDir.appendingPathComponent("records.json")
        try jsonData(for: items).write(to: jsonURL, options: .atomic)
        let pdfURL = workDir.appendingPathComponent("records.pdf")
        try pdfData(for: items).write(to: pdfURL, options: .atomic)

        // Copy attachments
        let attachmentsRoot = workDir.appendingPathComponent("attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsRoot, withIntermediateDirectories: true)
        for item in items {
            for attachment in (item.attachments ?? []) {
                let src = AttachmentStorage.url(for: attachment.filename)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let recordDir = attachmentsRoot.appendingPathComponent(item.id.uuidString, isDirectory: true)
                try? FileManager.default.createDirectory(at: recordDir, withIntermediateDirectories: true)
                let dest = recordDir.appendingPathComponent(attachment.originalName.isEmpty ? attachment.filename : attachment.originalName)
                try? FileManager.default.copyItem(at: src, to: dest)
            }
        }

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OPerationsHOS-\(UUID().uuidString).zip")

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var movedURL: URL?
        coordinator.coordinate(readingItemAt: workDir, options: .forUploading, error: &coordError) { tempZip in
            do {
                try? FileManager.default.removeItem(at: zipURL)
                try FileManager.default.moveItem(at: tempZip, to: zipURL)
                movedURL = zipURL
            } catch {
                movedURL = nil
            }
        }
        if let coordError { throw coordError }
        guard let result = movedURL else {
            throw NSError(domain: "OPerationsHOS.Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "ZIP coordination failed"])
        }
        return result
    }
}
