import Foundation

/// Per-record access grant to another user (a Person record flagged as a
/// share-recipient). Owner sets the permission level (read or read+write)
/// at share time; can modify or revoke later from the record's detail view
/// or wholesale from the Person's detail view in People CRM.
struct AccessGrant: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let personID: UUID
    var permission: AccessPermission
    var grantedDate: Date = Date()
}

enum AccessPermission: String, Codable, CaseIterable, Identifiable {
    case read
    case readWrite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .read: return "Read"
        case .readWrite: return "Read + Write"
        }
    }

    var description: String {
        switch self {
        case .read: return "Recipient sees the record; cannot edit."
        case .readWrite: return "Recipient sees and edits the record (changes sync back). Requires iMessage delivery."
        }
    }

    var symbol: String {
        switch self {
        case .read: return "eye"
        case .readWrite: return "square.and.pencil"
        }
    }
}
