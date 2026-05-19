//
//  TimerModulesApp.swift
//  TimerModules
//
//  Created by Michael Fluharty on 5/16/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct TimerModulesApp: App {
    init() {
        // Request permission to post local notifications (used by
        // Action cards configured with kind = notification).
        // Fire-and-forget; user can also grant later via Settings.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            GanttChartData.self,
            TimerModuleData.self,
            GateBrickData.self,
            TraceData.self,
            SupplementalBrickData.self,
            LogEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
