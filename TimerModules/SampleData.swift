import Foundation
import SwiftData

enum SampleData {
    /// Hardcoded UUIDs so the populate function is idempotent —
    /// re-running it adds back any deleted samples without duplicating ones already present.
    private static let id1  = UUID(uuidString: "11111111-1111-1111-1111-000000000001")!
    private static let id2  = UUID(uuidString: "11111111-1111-1111-1111-000000000002")!
    private static let id3  = UUID(uuidString: "11111111-1111-1111-1111-000000000003")!
    private static let id4  = UUID(uuidString: "11111111-1111-1111-1111-000000000004")!
    private static let id5  = UUID(uuidString: "11111111-1111-1111-1111-000000000005")!
    private static let id6  = UUID(uuidString: "11111111-1111-1111-1111-000000000006")!
    private static let id7  = UUID(uuidString: "11111111-1111-1111-1111-000000000007")!
    private static let id8  = UUID(uuidString: "11111111-1111-1111-1111-000000000008")!
    private static let id9  = UUID(uuidString: "11111111-1111-1111-1111-000000000009")!
    private static let id10 = UUID(uuidString: "11111111-1111-1111-1111-000000000010")!
    private static let id11 = UUID(uuidString: "11111111-1111-1111-1111-000000000011")!
    private static let id12 = UUID(uuidString: "11111111-1111-1111-1111-000000000012")!
    private static let id13 = UUID(uuidString: "11111111-1111-1111-1111-000000000013")!
    private static let id14 = UUID(uuidString: "11111111-1111-1111-1111-000000000014")!
    private static let id15 = UUID(uuidString: "11111111-1111-1111-1111-000000000015")!

    static let sampleIDs: Set<UUID> = [
        id1, id2, id3, id4, id5, id6, id7, id8, id9, id10, id11, id12, id13, id14, id15
    ]

    /// Exposed so OperatorStore can find the Media sample after populate
    /// to attach the bundled placeholder diagram.
    static let propertyPhotoSetID: UUID = id10

    @MainActor
    static func allSamples() -> [OperatorItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let inDays: (Int) -> Date = { cal.date(byAdding: .day, value: $0, to: today)! }
        let nextSunday = cal.nextDate(after: today, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime) ?? inDays(7)
        let nextMonday = cal.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? inDays(1)

        return [
            // 1. Note — a quick reference jotted somewhere
            OperatorItem(
                id: id1,
                title: "Read the Solar Inverter Manual",
                subtitle: "Understand the warranty terms",
                body: "The inverter is the brain of the solar setup. The warranty covers the inverter for ten years; the panels for twenty-five. Skim the manual before something fails.",
                type: .note,
                status: .open,
                priority: .low,
                createdDate: inDays(-3),
                updatedDate: inDays(-3),
                tags: ["solar", "reference"]
            ),

            // 2. Task — something concrete to do
            OperatorItem(
                id: id2,
                title: "Replace HVAC Air Filter",
                subtitle: "Quarterly maintenance",
                body: "Sixteen-by-twenty-by-one. Cheap pleated filter is fine — high-MERV ones starve the blower on this unit.",
                type: .task,
                status: .open,
                priority: .normal,
                createdDate: inDays(-7),
                updatedDate: inDays(-7),
                dueDate: inDays(5),
                tags: ["hvac", "maintenance"],
                relatedSystem: "HVAC"
            ),

            // 3. Document — a record of something on file
            OperatorItem(
                id: id3,
                title: "Solar Array Invoice",
                subtitle: "Final invoice still missing",
                body: "Installer hasn't sent the final invoice. Need this for property records and warranty claims. Follow up next week.",
                type: .document,
                status: .waiting,
                priority: .normal,
                createdDate: inDays(-21),
                updatedDate: inDays(-7),
                dueDate: inDays(3),
                tags: ["solar", "invoice"],
                relatedSystem: "Solar"
            ),

            // 4. Warranty — coverage you want to remember
            OperatorItem(
                id: id4,
                title: "HVAC Coil Warranty",
                subtitle: "Active until 03/31/2027",
                body: "Coil leak found in March. Replacement pending. Warranty confirmed through 03/31/2027. Keep this record handy when scheduling future service calls.",
                type: .warranty,
                status: .active,
                priority: .high,
                createdDate: inDays(-14),
                updatedDate: inDays(-2),
                pinned: true,
                tags: ["hvac", "warranty"],
                relatedSystem: "HVAC"
            ),

            // 5. Appliance — a specific unit you own
            OperatorItem(
                id: id5,
                title: "Refrigerator Replacement",
                subtitle: "Delivery scheduled 10 AM – 2 PM",
                body: "Replacement model ordered. Old unit pickup confirmed for the same window. Receipt and warranty packet due from the retailer.",
                type: .appliance,
                status: .scheduled,
                priority: .high,
                createdDate: inDays(-10),
                updatedDate: inDays(-1),
                dueDate: inDays(2),
                pinned: true,
                tags: ["kitchen", "appliance"],
                relatedSystem: "Kitchen"
            ),

            // 6. Home System — a whole subsystem of the house
            OperatorItem(
                id: id6,
                title: "HVAC System",
                subtitle: "3-ton split, installed 2019",
                body: "Outdoor condenser is in the side yard. Indoor air handler in the attic. Service vendor on file.",
                type: .homeSystem,
                status: .active,
                priority: .normal,
                createdDate: inDays(-180),
                updatedDate: inDays(-2),
                tags: ["hvac"],
                relatedSystem: "HVAC"
            ),

            // 7. Maintenance — a low-stakes ongoing fix
            OperatorItem(
                id: id7,
                title: "Guest Bath Sink Drip",
                subtitle: "Hot-side drip, low priority",
                body: "Hot side drips. Cartridge replacement is the likely fix. Not urgent but should clear before any walk-through.",
                type: .maintenance,
                status: .open,
                priority: .low,
                createdDate: inDays(-5),
                updatedDate: inDays(-5),
                tags: ["plumbing", "guest-bath"],
                relatedSystem: "Plumbing"
            ),

            // 8. Project — an ongoing initiative with multiple steps
            OperatorItem(
                id: id8,
                title: "Property Sale Prep",
                subtitle: "Wash, document, stage",
                body: "Wash exterior. Gather all home documents. Fix the guest sink drip. Stage interior. Collect solar paperwork. Inspection scheduled next month.",
                type: .project,
                status: .active,
                priority: .high,
                createdDate: inDays(-30),
                updatedDate: today,
                pinned: true,
                tags: ["sale", "prep"],
                relatedSystem: "Property"
            ),

            // 9. Week in Summary — Sunday retrospective (backward-look)
            OperatorItem(
                id: id9,
                title: "Sunday Week in Summary",
                subtitle: "What happened, what got done",
                body: "End-of-week reflection. Note what you finished, what stalled, what you learned. Carry unresolved items into next week. No timer — this is reflection, not a sprint.",
                type: .task,
                status: .active,
                priority: .normal,
                createdDate: inDays(-60),
                updatedDate: today,
                dueDate: nextSunday,
                tags: ["workflow", "weekly", "retrospective"]
            ),

            // 10. Media — a photo, video, or piece of content tied to a record
            OperatorItem(
                id: id10,
                title: "Property Photo Set",
                subtitle: "Front, back, side yard",
                body: "Wide-angle shots taken in afternoon light. Use these for the property records and any future listing materials.",
                type: .media,
                status: .complete,
                priority: .low,
                createdDate: inDays(-12),
                updatedDate: inDays(-12),
                tags: ["photos", "property"]
            ),

            // 11. Property — the home itself
            OperatorItem(
                id: id11,
                title: "Beachview Cottage",
                subtitle: "Primary residence",
                body: "Two-bedroom one-bath cottage near the coast. Built mid-century, renovated in stages. Solar, fiber internet, recent HVAC.",
                type: .property,
                status: .active,
                priority: .normal,
                createdDate: inDays(-365),
                updatedDate: inDays(-7),
                pinned: true,
                tags: ["home"]
            ),

            // 12. Person — a contact who interacts with the home
            OperatorItem(
                id: id12,
                title: "Sam Acme — HVAC Contractor",
                subtitle: "Last call about coil leak",
                body: "Came out for the coil leak. Confirmed warranty coverage. Reliable, calls back same day. Number is on file.",
                type: .person,
                status: .active,
                priority: .normal,
                createdDate: inDays(-90),
                updatedDate: inDays(-2),
                tags: ["hvac", "contractor"],
                relatedSystem: "HVAC"
            ),

            // 13. Plan of the Week — Monday forward-look (planning)
            OperatorItem(
                id: id13,
                title: "Monday Plan of the Week",
                subtitle: "Set priorities and schedule focus time",
                body: "Start-of-week planning. Pick the two or three things that must move this week. Block focus time. Clear the inbox to zero. No timer — this is intent-setting, not a sprint.",
                type: .task,
                status: .active,
                priority: .high,
                createdDate: inDays(-60),
                updatedDate: today,
                dueDate: nextMonday,
                tags: ["workflow", "weekly", "planning"]
            ),

            // 14. Focus Cycle 25 / 5 — preset focus timer
            OperatorItem(
                id: id14,
                title: "Focus Cycle 25 / 5",
                subtitle: "Twenty-five minutes focus + five minute break",
                body: "Twenty-five minutes of single-task focus, five-minute break, repeat. Four cycles equals one set.",
                type: .timer,
                status: .open,
                priority: .normal,
                createdDate: inDays(-30),
                updatedDate: inDays(-30),
                tags: ["focus", "cycle", "preset"]
            ),

            // 15. Long Focus Session — preset extended focus
            OperatorItem(
                id: id15,
                title: "Long Focus Session",
                subtitle: "Single-task focus block",
                body: "Extended single-task focus block. Phone off, notifications muted. Used for hard cognitive work.",
                type: .timer,
                status: .open,
                priority: .normal,
                createdDate: inDays(-30),
                updatedDate: inDays(-30),
                tags: ["focus", "extended", "preset"]
            )
        ]
    }
}
