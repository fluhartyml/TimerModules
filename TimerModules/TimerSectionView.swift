import SwiftUI
import Combine

struct TimerSectionView: View {
    let item: OperatorItem
    let store: OperatorStore

    @State private var tick = Date()
    @State private var sweepAngle: Double = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval {
        var total = item.accumulatedSeconds
        if let started = item.runningSince {
            total += tick.timeIntervalSince(started)
        }
        return total
    }

    private var formatted: String {
        let total = Int(elapsed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private var isRunning: Bool {
        item.runningSince != nil
    }

    private var linkedProject: OperatorItem? {
        guard let id = item.linkedRecordID else { return nil }
        return store.items.first(where: { $0.id == id && $0.type == .project })
    }

    private var allProjects: [OperatorItem] {
        store.items
            .filter { !$0.archived && $0.type == .project }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Timer").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            analogDial

            startStopReset

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("Project").foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("None") {
                        store.linkTimer(item.id, toRecord: nil)
                    }
                    ForEach(allProjects) { project in
                        Button(project.title) {
                            store.linkTimer(item.id, toRecord: project.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(linkedProject?.title ?? "Link…")
                            .foregroundStyle(linkedProject == nil ? Color.secondary : Color.accentColor)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .onReceive(timer) { now in
            if isRunning {
                tick = now
            }
        }
    }

    /// Circular analog dial: muted background ring, accent-colored sweep arc that
    /// rotates while the timer is running. Time text reads from the center.
    /// Egg-timer affordance — graphic-first rather than digit-only.
    private var analogDial: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 10, lineCap: .round))

            Circle()
                .trim(from: 0, to: 0.18)
                .stroke(
                    isRunning ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(sweepAngle - 90))
                .animation(isRunning ? .linear(duration: 2.5).repeatForever(autoreverses: false) : .default, value: sweepAngle)

            VStack(spacing: 4) {
                Text(formatted)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRunning ? Color.accentColor : .primary)
                    .contentTransition(.numericText())
                Text(isRunning ? "Running" : (elapsed > 0 ? "Paused" : "Idle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 220, height: 220)
        .frame(maxWidth: .infinity)
        .onAppear {
            if isRunning {
                sweepAngle = 360
            }
        }
        .onChange(of: isRunning) { _, nowRunning in
            sweepAngle = nowRunning ? 360 : 0
        }
    }

    private var startStopReset: some View {
        HStack(spacing: 12) {
            if isRunning {
                Button {
                    store.stopTimer(id: item.id)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    store.startTimer(id: item.id)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if !isRunning && item.accumulatedSeconds > 0 {
                Button(role: .destructive) {
                    store.resetTimer(id: item.id)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
