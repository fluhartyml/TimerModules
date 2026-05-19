import Foundation
import Observation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Wrapper around AlarmManager.shared for OPerationsHOS Timer integration.
/// AlarmKit availability requires iOS 26+; older runtimes get a stub.
@MainActor
@Observable
final class AlarmKitManager {
    static let shared = AlarmKitManager()

    var authorized: Bool = false
    var lastError: String?

    private init() {}

    func refreshAuthorization() async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, iPadOS 26.0, macCatalyst 26.0, *) {
            let state = AlarmManager.shared.authorizationState
            authorized = (state == .authorized)
        }
        #endif
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, iPadOS 26.0, macCatalyst 26.0, *) {
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                authorized = (state == .authorized)
                return authorized
            } catch {
                lastError = error.localizedDescription
                return false
            }
        }
        #endif
        return false
    }

    /// Schedules a system-level countdown timer for the given OPerationsHOS Timer record.
    /// Returns the alarm ID so the caller can persist it for cancellation later.
    func scheduleTimer(for item: OperatorItem, duration: TimeInterval) async -> UUID? {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, iPadOS 26.0, macCatalyst 26.0, *) {
            if !authorized { _ = await requestAuthorization() }
            guard authorized else { return nil }

            let alarmID = UUID()
            do {
                let attributes = AlarmAttributes<OPerationsHOSAlarmMetadata>(
                    presentation: AlarmPresentation(
                        alert: AlarmPresentation.Alert(
                            title: LocalizedStringResource(stringLiteral: item.title),
                            stopButton: .stopButton
                        )
                    ),
                    metadata: OPerationsHOSAlarmMetadata(itemID: item.id.uuidString),
                    tintColor: .blue
                )
                let configuration = AlarmManager.AlarmConfiguration<OPerationsHOSAlarmMetadata>.timer(
                    duration: duration,
                    attributes: attributes
                )
                _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
                return alarmID
            } catch {
                lastError = error.localizedDescription
                return nil
            }
        }
        #endif
        return nil
    }

    func cancelTimer(id: UUID) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, iPadOS 26.0, macCatalyst 26.0, *) {
            try? AlarmManager.shared.cancel(id: id)
        }
        #endif
    }
}

#if canImport(AlarmKit)
import ActivityKit

struct OPerationsHOSAlarmMetadata: AlarmMetadata {
    let itemID: String
}
#endif

#if canImport(AlarmKit)
extension AlarmButton {
    static var stopButton: AlarmButton {
        AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
    }
}
#endif
