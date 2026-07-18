import SwiftUI
import WorldTrackerKit

/// The full-screen moment when a brand-new country enters the log:
/// scrim + aurora flare, a stamped-in flag, "COUNTRY #N", and a door
/// straight to the map.
struct NewCountryCelebrationView: View {
    let celebration: CelebrationCoordinator.Celebration
    let onSeeWorld: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false
    @State private var shareURL: URL?

    private let duration: Double = 2.2

    var body: some View {
        Group {
            if reduceMotion {
                content(1)
            } else {
                TimelineView(.animation(paused: finished)) { timeline in
                    let p = min(1, timeline.date.timeIntervalSince(start) / duration)
                    content(p)
                        .onChange(of: p >= 1) { _, done in
                            if done { finished = true }
                        }
                }
            }
        }
        .onAppear {
            HapticsDirector.shared.celebrate()
            // Render during the stamp animation so the URL is ready before
            // the buttons reveal (~1.6s in).
            shareURL = ShareCardService.render(
                CelebrationShareCard(
                    code: celebration.countryCode,
                    number: celebration.number,
                    dateText: Date.now.formatted(date: .long, time: .omitted)
                ),
                name: "BeenThere-Country-\(celebration.number)"
            )
        }
    }

    private func content(_ p: Double) -> some View {
        ZStack {
            // Scrim + flare.
            Theme.sky.opacity(0.6 + 0.32 * reveal(p, 0, 0.2))
                .ignoresSafeArea()
            AuroraBackground(intensity: 1.1)
                .opacity(0.85 * reveal(p, 0, 0.3))

            AuroraBurstView(progress: reveal(p, 0.15, 0.8), particleCount: 96)
                .frame(width: 360, height: 360)

            VStack(spacing: 18) {
                Spacer()

                stampFlag(p)

                Text("COUNTRY #\(celebration.number)")
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.amber)
                    .opacity(reveal(p, 0.35, 0.5))

                Text(countryName(celebration.countryCode))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .opacity(reveal(p, 0.4, 0.55))
                    .offset(y: (1 - easeOut(reveal(p, 0.4, 0.6))) * 18)

                if let city = celebration.city {
                    Text("Starting in \(city)")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink2)
                        .opacity(reveal(p, 0.55, 0.7))
                }

                Spacer()

                Button {
                    onSeeWorld()
                } label: {
                    Text("See your world →")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.sky)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 28)
                .opacity(reveal(p, 0.7, 0.85))

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share this moment", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.aurora1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Theme.aurora1.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 28)
                    .opacity(reveal(p, 0.72, 0.87))
                }

                Button("Keep exploring") {
                    onDismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .padding(.bottom, 28)
                .opacity(reveal(p, 0.75, 0.9))
            }
            .padding(.horizontal, 24)
        }
    }

    private func stampFlag(_ p: Double) -> some View {
        let slam = easeOutBack(reveal(p, 0.12, 0.32))
        return FlagChip(code: celebration.countryCode, size: 110)
            .shadow(color: Theme.aurora1.opacity(0.5), radius: 26)
            .scaleEffect(2.4 - 1.4 * slam)
            .rotationEffect(.degrees((1 - slam) * -14))
            .opacity(reveal(p, 0.12, 0.22))
            .modifier(SlamHaptic(fired: slam >= 1))
    }

    private func reveal(_ p: Double, _ from: Double, _ to: Double) -> Double {
        guard to > from else { return p >= to ? 1 : 0 }
        return min(1, max(0, (p - from) / (to - from)))
    }

    private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

private struct SlamHaptic: ViewModifier {
    let fired: Bool

    func body(content: Content) -> some View {
        content.onChange(of: fired) { _, now in
            if now { HapticsDirector.shared.stampSlam() }
        }
    }
}
