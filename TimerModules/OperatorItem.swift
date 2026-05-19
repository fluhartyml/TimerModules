import Foundation
import SwiftData

@Model
final class OperatorItem {
    var id: UUID = UUID()
    var title: String = ""
    var subtitle: String = ""
    var body: String = ""
    var type: ItemType = ItemType.note
    var status: ItemStatus = ItemStatus.open
    var priority: ItemPriority = ItemPriority.normal
    var createdDate: Date = Date()
    var updatedDate: Date = Date()
    var dueDate: Date?
    var pinned: Bool = false
    var archived: Bool = false
    var isSecure: Bool = false
    var tags: [String] = []
    /// JSON-encoded `[AccessGrant]`. Storage form so SwiftData stays happy; use
    /// the `accessGrants` computed property for typed reads/writes.
    var accessGrantsJSON: String = "[]"
    var relatedSystem: String?
    var source: String?

    // Phase 12 — Timer / Workflow
    var accumulatedSeconds: Double = 0
    var runningSince: Date?
    var linkedRecordID: UUID?

    // Phase 20 / 21 — EventKit two-way sync identifiers
    var eventIdentifier: String?
    var reminderIdentifier: String?

    // Phase 22 — AlarmKit countdown timer target
    var alarmTargetSeconds: Double?
    var alarmIdentifier: String?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.owner)
    var attachments: [Attachment]? = []

    @Relationship(deleteRule: .cascade, inverse: \ActivityEvent.owner)
    var events: [ActivityEvent]? = []

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        body: String = "",
        type: ItemType,
        status: ItemStatus = .open,
        priority: ItemPriority = .normal,
        createdDate: Date = Date(),
        updatedDate: Date = Date(),
        dueDate: Date? = nil,
        pinned: Bool = false,
        archived: Bool = false,
        isSecure: Bool = false,
        tags: [String] = [],
        relatedSystem: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.type = type
        self.status = status
        self.priority = priority
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.dueDate = dueDate
        self.pinned = pinned
        self.archived = archived
        self.isSecure = isSecure
        self.tags = tags
        self.relatedSystem = relatedSystem
        self.source = source
    }

    /// Typed accessor over `accessGrantsJSON`. Decodes lazily on read, encodes on write.
    var accessGrants: [AccessGrant] {
        get {
            guard let data = accessGrantsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([AccessGrant].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                accessGrantsJSON = str
            } else {
                accessGrantsJSON = "[]"
            }
        }
    }
}

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case note
    case task
    case document
    case warranty
    case appliance
    case homeSystem
    case maintenance
    case project
    case timer
    case media
    case property
    case person
    case secureNote
    case transcription

    var id: String { rawValue }

    var label: String {
        switch self {
        case .note: return "Note"
        case .task: return "Task"
        case .document: return "Document"
        case .warranty: return "Warranty"
        case .appliance: return "Appliance"
        case .homeSystem: return "Home System"
        case .maintenance: return "Maintenance"
        case .project: return "Project"
        case .timer: return "Timer"
        case .media: return "Media"
        case .property: return "Property"
        case .person: return "Person"
        case .secureNote: return "Secure Note"
        case .transcription: return "Transcription"
        }
    }

    var symbol: String {
        switch self {
        case .note: return "note.text"
        case .task: return "checklist"
        case .document: return "doc.text"
        case .warranty: return "shield"
        case .appliance: return "refrigerator"
        case .homeSystem: return "house"
        case .maintenance: return "wrench.and.screwdriver"
        case .project: return "square.stack.3d.up"
        case .timer: return "timer"
        case .media: return "photo"
        case .property: return "building.2"
        case .person: return "person.crop.circle.fill"
        case .secureNote: return "lock.doc"
        case .transcription: return "waveform"
        }
    }

    /// Types that live only inside the biometrically-gated Vault.
    var isVaultOnly: Bool {
        switch self {
        case .media, .secureNote, .transcription: return true
        default: return false
        }
    }
}

enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case active
    case waiting
    case scheduled
    case complete
    case archived

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Open"
        case .active: return "Active"
        case .waiting: return "Waiting"
        case .scheduled: return "Scheduled"
        case .complete: return "Complete"
        case .archived: return "Archived"
        }
    }
}

enum ItemPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case normal
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
}
