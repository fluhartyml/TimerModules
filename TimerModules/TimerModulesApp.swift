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
            StartBrickData.self,
            DelayBrickData.self,
            TextLCDBrickData.self,
            GlyphLCDBrickData.self,
            DigitalClockBrickData.self,
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

        // Secondary window for the per-chart execution log. On Mac
        // this gives the log full window chrome (traffic lights,
        // drag-to-move, close button) — fixes the issues Michael
        // flagged with the sheet-based presentation 2026-05-19.
        // On iOS / iPadOS this is the same scene; users with multi-
        // window support can open the log in a separate window.
        WindowGroup("Timer Module Log", id: "logWindow", for: LogWindowID.self) { $payload in
            if let p = payload {
                LogView(chartId: p.chartId, chartName: p.chartName)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
