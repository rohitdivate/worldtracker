import SwiftUI
import WorldTrackerKit

/// The cold-launch moment: night sky, then the world ignites west→east —
/// every country you've visited catching aurora, home flaring amber — and
/// the wordmark stamps in before the app fades up underneath. ~1.6s, tap
/// anywhere to skip, a single static frame under Reduce Motion.
struct LaunchOverlayView: View {
    /// Called exactly once, when the show ends (or is skipped).
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false
    @State private var tickFired = false
    @State private var dots: [WorldDotGrid.Dot] = []
    @State private var visited: [String: Int] = [:]
    @State private var home: String?

    private static let columns = 66
    private static let rows = 30
    private let duration: Double = 1.6

    var body: some View {
        Group {
            if reduceMotion {
                content(1)
                    .task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        finish()
                    }
            } else {
                TimelineView(.animation(paused: finished)) { timeline in
                    let p = min(1, timeline.date.timeIntervalSince(start) / duration)
                    content(p)
                        .onChange(of: p >= 1) { _, done in
                            if done { finish() }
                        }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            let store = AppContainer.shared.ledgerStore
            let today = store.todayEpoch
            let earliest = min(store.earliestDay ?? today, today)
            visited = store.stats(in: earliest...today).daysPerCountry
            home = store.homeCountry
            dots = await Task.detached(priority: .userInitiated) {
                guard let shapes = try? WorldMapShapes() else { return [] }
                return WorldDotGrid.compute(
                    shapes: shapes, columns: Self.columns, rows: Self.rows
                )
            }.value
        }
    }

    private func content(_ p: Double) -> some View {
        ZStack {
            Theme.sky.ignoresSafeArea()
            StaticAurora()
                .opacity(0.55 * reveal(p, 0, 0.35))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                dotWorld(p)
                    .frame(height: 200)
                    .padding(.horizontal, 26)
                Spacer()
            }

            wordmark(p)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 90)
        }
    }

    /// West→east ignition sweep over the shared dot painter.
    private func dotWorld(_ p: Double) -> some View {
        Canvas { context, size in
            guard !dots.isEmpty else { return }
            // The sweep finishes at 65% of the show; glow blooms after.
            let sweep = reveal(p, 0.05, 0.65)
            let bloom = reveal(p, 0.6, 0.9)
            let maxDays = visited.values.max() ?? 1
            let radius = min(
                size.width / CGFloat(Self.columns) * 0.32,
                size.height / CGFloat(Self.rows) * 0.32
            )

            for dot in dots {
                // Each dot appears as the sweep line passes its longitude.
                let appear = sweep * 1.25 - dot.unitX
                guard appear > 0 else { continue }
                let alpha = min(1, appear * 6)
                let center = CGPoint(
                    x: CGFloat(dot.unitX) * size.width,
                    y: CGFloat(dot.unitY) * size.height
                )

                let isHome = dot.code == home
                let days = visited[dot.code]
                let color: Color
                if isHome {
                    color = Theme.amber
                } else if let days {
                    color = Theme.aurora1.opacity(0.55 + 0.45 * Double(days) / Double(maxDays))
                } else {
                    color = Theme.ink3.opacity(0.32)
                }

                if bloom > 0, isHome || days != nil {
                    let glow = radius * (2.2 + 1.4 * bloom)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - glow, y: center.y - glow,
                            width: glow * 2, height: glow * 2
                        )),
                        with: .color((isHome ? Theme.amber : Theme.aurora1)
                            .opacity(0.10 * bloom * alpha))
                    )
                }
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )),
                    with: .color(color.opacity(alpha))
                )
            }
        }
    }

    private func wordmark(_ p: Double) -> some View {
        let slam = easeOutBack(reveal(p, 0.5, 0.72))
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                MiniGlobe(size: 22, showsPlane: false)
                Text("BEEN THERE")
                    .font(Theme.numeric(17, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(Theme.ink)
            }
            Text("YOUR WORLD, QUIETLY LOGGED")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Theme.ink3)
                .opacity(reveal(p, 0.68, 0.85))
        }
        .scaleEffect(1.25 - 0.25 * slam)
        .opacity(reveal(p, 0.5, 0.62))
        .modifier(LaunchTick(fired: slam >= 1 && !reduceMotion))
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }

    private func reveal(_ p: Double, _ from: Double, _ to: Double) -> Double {
        guard to > from else { return p >= to ? 1 : 0 }
        return min(1, max(0, (p - from) / (to - from)))
    }

    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

private struct LaunchTick: ViewModifier {
    let fired: Bool

    func body(content: Content) -> some View {
        content.onChange(of: fired) { _, now in
            if now { HapticsDirector.shared.tick() }
        }
    }
}
