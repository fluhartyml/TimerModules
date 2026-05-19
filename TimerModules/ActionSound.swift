// MARK: - ActionSound
//
// Curated set of system sounds the user can pick for an
// Action card's sound kind. Per Michael 2026-05-19: "maybe
// the user can choose one of the predefined iphone sounds
// like an email being sent or a new chat message has arrived
// or a reminder event."
//
// rawValue is the user-facing name (also stored in the
// SupplementalBrickData.configString field when kind = sound).
// soundID is the AudioServices SystemSoundID Apple ships in
// the iOS / macOS standard library.

import Foundation
import AVFoundation

enum ActionSound: String, CaseIterable, Identifiable {
    case mailSent         = "Mail Sent"
    case newMail          = "New Mail"
    case messageReceived  = "Message Received"
    case reminderAlert    = "Reminder"
    case calendarAlert    = "Calendar Alert"
    case tweet            = "Tweet"
    case bell             = "Bell"
    case glass            = "Glass"
    case anticipate       = "Anticipate"
    case bloom            = "Bloom"
    case calypso          = "Calypso"
    case note             = "Note"

    var id: String { rawValue }

    var soundID: SystemSoundID {
        switch self {
        case .mailSent:         return 1004
        case .newMail:          return 1000
        case .messageReceived:  return 1003
        case .reminderAlert:    return 1005
        case .calendarAlert:    return 1335
        case .tweet:            return 1016
        case .bell:             return 1013
        case .glass:            return 1009
        case .anticipate:       return 1020
        case .bloom:            return 1021
        case .calypso:          return 1022
        case .note:             return 1322
        }
    }

    /// Default if the user hasn't picked one yet.
    static let `default`: ActionSound = .reminderAlert
}
