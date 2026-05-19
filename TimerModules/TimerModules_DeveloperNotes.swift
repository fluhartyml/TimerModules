// MARK: - TimerModules — Developer Notes
// Version: 0.0 (pre-MVP — design locked, build pending)
// Developer: Michael Lee Fluharty
// License: GPL v3
// Created: 2026-05-16
// Lineage: starts as a copy of OPerationsHOS
// Repo: github.com/fluhartyml/TimerModules (NightGard namespace)
//
// Companion roadmap (active program):
//   apartment Workshop/TimerModules-Roadmap-DRAFT-2026-05-19.html
//
// ============================================================
// LINEAGE FROM OPerationsHOS
// ============================================================
//
// Starting point: copy all the code from OPerationsHOS into
// TimerModules (Michael 2026-05-19). Adapt from there for the
// TimerModules brick-based architecture; don't start from
// scratch. Coding mechanics handled at Claude's lane.
//
// Do NOT modify OPerationsHOS itself as part of this work
// (ain't-broke-don't-fix-it).
//
// ============================================================
// VISION — LOCKED 2026-05-19
// ============================================================
//
// PARENT UI SHAPE: Gantt chart.
//   Multi-timer rows on a shared time axis.
//
// COMPOSITION MODEL: user-Lego.
//   The app ships with a palette of bricks. The user drags
//   them onto the Gantt canvas and snaps them together at
//   runtime — the user is the snapper, not the developer.
//
// DISTINCTIVE TWIST: two complementary connector sub-families.
//   Logic gates (boolean operations on completions) AND PM
//   dependency types (event-type semantics) — both available
//   as snap-together bricks. Most PM tools have one or the
//   other; TimerModules has both. They compose.
//
// ============================================================
// BRICK PALETTE — ALL LOCKED FOR v1.0
// ============================================================
//
// Family 1 — FUNCTIONAL
//   • Timer module — the main brick. Also called "clock" —
//     Michael uses both names interchangeably for the same
//     brick. Runs time (countdown OR count-up, both supported).
//     Acts as the steady-signal-source / timekeeping baseline.
//     Includes a prominent, obvious user-notation text field
//     on the brick face so each timer can be labeled.
//
// Family 2a — CONNECTORS · Logic gates
//   All seven boolean gates ship in v1.0:
//     AND, OR, NOT, NOR, NAND, XOR, XNOR.
//
// Family 2b — CONNECTORS · PM dependency types
//   All PM types ship in v1.0:
//     FS  — Finish-to-Start (default Gantt edge)
//     SS  — Start-to-Start (parallel kickoff)
//     FF  — Finish-to-Finish (synced ending)
//     SF  — Start-to-Finish (fourth standard type)
//     Lag/Lead  — offset on any edge
//     Splitter / Fan-out  — own brick (one→many)
//
// Family 3 — SUPPLEMENTAL
//   All supplemental bricks ship in v1.0:
//     • Note          — text label / sticky-note
//     • Marker        — milestone diamond on the timeline
//     • Trigger       — entry-point brick (manual / scheduled / external)
//     • Action        — side-effect brick (sound, notification, log, link)
//     • Group         — container that wraps a sub-Gantt under one label
//     • Variable      — counter that tracks state across runs
//     • Webhook       — network-action brick (HTTP outbound)
//     • Conditional   — explicit if-then-else with named branches
//     • Loop          — repeat a section N times or until a condition
//
// ============================================================
// BEHAVIOR & DISTRIBUTION — LOCKED
// ============================================================
//
//   PERSISTENCE: SwiftData. Timers, canvases, bricks and their
//   layouts survive app close.
//
//   ALARM / NOTIFICATION: All three modes ship — silent (visual
//   only), audible (haptic + sound), and system notification.
//   User selects per timer. Foreground + background both
//   supported.
//
//   DISTRIBUTION: App Store, paid product. Ship deadline
//   ~2026-06-10 (submission-ready) for Apple review before
//   ~2026-06-15 subscription renewal. Schedule is load-bearing
//   — if behind, Michael will most likely not renew.
//
// ============================================================
// MILESTONE SEQUENCE
// ============================================================
//
//   M0 — Scaffold cleanup. Copy HOS codebase into TimerModules.
//        Commit dirty project.pbxproj. Add README using
//        CryoTunes wiki template. This file already exists.
//
//   M1 — Timer module brick. Adapt the HOS Timer view into the
//        standalone Timer module brick (with user-notation text
//        field). One brick on screen, start/stop/reset working,
//        persists via SwiftData.
//
//   M2 — Gantt canvas + user-Lego. Build the canvas that hosts
//        bricks. Palette + drag-and-drop placement + snap-to-row.
//        User can place multiple Timer modules and label each.
//
//   M3 — Logic-gate connector bricks. Implement AND, OR, NOT,
//        NOR, NAND, XOR, XNOR as snap-together bricks. Wire up
//        boolean-on-completion logic.
//
//   M4 — PM-dependency connector bricks. Implement FS, SS, FF,
//        SF, Lag/Lead, Splitter/Fan-out. Edge rendering on canvas.
//
//   M5 — Supplemental bricks. Implement Note, Marker, Trigger,
//        Action, Group, Variable, Webhook, Conditional, Loop.
//        Trigger especially — every runnable canvas needs one.
//
//   M6 — Alarm / notification. Silent / audible / system
//        notification, user-selectable per timer, foreground +
//        background.
//
//   M7 — Platform pass. Verify universal build on iPhone, iPad,
//        Mac. Adapt layout per platform (HOS pattern).
//
//   M8 — Documentation. Sync this file → wiki Developer-Notes.md.
//        Quick Start (Xcode 26 paste-URL flow). About page with
//        logo + Claude easter egg.
//
//   M9 — Ship prep. Icons (light + dark, no tinted). 1242×2688
//        screenshots (no third-party IP). Privacy at
//        fluharty.me/timermodules-privacy. Support at
//        fluharty.me/timermodules-support built as a
//        Chilton/Haynes-style owner's manual — exploded diagrams
//        of bricks, step-by-step procedures for common Gantts,
//        troubleshooting trees, comprehensive feature docs.
//        GPL v3 license file. App Store Connect setup.
//        Submission-ready by ~2026-06-10.
//
// ============================================================
// DISCIPLINE (carries forward from HOS + Michael's standing rules)
// ============================================================
//
//   • Universal target (iOS + iPadOS + macOS), single source tree.
//   • 18pt minimum font height (iPad readability standard).
//   • No tinted icons — light + dark only.
//   • One concern at a time; no extra abstractions / managers /
//     coordinators ahead of need.
//   • Don't modify OPerationsHOS as part of TimerModules work.
//   • Don't optimize ahead of the current milestone.
//   • Sync this file → wiki Developer-Notes.md after every change.
//   • Maximum quality bar — build at the highest standard
//     regardless of price (free, paid, demo). Price is
//     Michael's lane; quality has no discount tier.

import Foundation

/// Placeholder symbol so this file can live in the target without
/// being unreferenced. The real content above is the comment block.
enum TimerModulesDeveloperNotes {
    static let version = "0.0"
}
