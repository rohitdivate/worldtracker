import SwiftUI
import WorldTrackerKit

/// The milestone moment: burst + slam like COUNTRY #N, but the hero is a
/// lifetime number — "10 COUNTRIES", "25% OF THE WORLD", "500 TRAVEL DAYS",
/// or a new longest trip.
struct MilestoneCelebrationView: View {
    let moment: CelebrationCoordinator.MilestoneMoment
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
            shareURL = ShareCardService.render(
                MilestoneShareCard(
                    milestone: moment.milestone,
                    flags: moment.flags,
                    dateText: Date.now.formatted(date: .long, time: .omitted)
                ),
                name: "BeenThere-Milestone"
            )
        }
    }

    private func content(_ p: Double) -> some View {
        ZStack {
            Theme.sky.opacity(0.6 + 0.32 * reveal(p, 0, 0.2))
                .ignoresSafeArea()
            AuroraBackground(intensity: 1.1)
                .opacity(0.85 * reveal(p, 0, 0.3))

            AuroraBurstView(progress: reveal(p, 0.15, 0.8), particleCount: 96)
                .frame(width: 360, height: 360)

            VStack(spacing: 18) {
                Spacer()

                slamValue(p)

                Text(headline)
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.amber)
                    .opacity(reveal(p, 0.35, 0.5))

                Text(subline)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .opacity(reveal(p, 0.5, 0.65))

                flagCascade
                    .opacity(reveal(p, 0.55, 0.7))

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

    private func slamValue(_ p: Double) -> some View {
        let slam = easeOutBack(reveal(p, 0.12, 0.32))
        return Text(bigValue)
            .font(.system(size: 74, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.auroraGradient)
            .shadow(color: Theme.aurora1.opacity(0.5), radius: 26)
            .scaleEffect(2.2 - 1.2 * slam)
            .rotationEffect(.degrees((1 - slam) * -8))
            .opacity(reveal(p, 0.12, 0.22))
            .modifier(MilestoneSlamHaptic(fired: slam >= 1))
    }

    @ViewBuilder
    private var flagCascade: some View {
        if !moment.flags.isEmpty {
            HStack(spacing: 6) {
                ForEach(moment.flags.prefix(9), id: \.self) { code in
                    Text(flagEmoji(code)).font(.system(size: 20))
                }
            }
        }
    }

    private var bigValue: String {
        switch moment.milestone {
        case .countryCount(let n): return "\(n)"
        case .travelDays(let n): return "\(n)"
        case .worldPercent(let p): return "\(p)%"
        case .longestTripBeaten(let days, _): return "\(days)"
        }
    }

    private var headline: String {
        switch moment.milestone {
        case .countryCount: return "COUNTRIES"
        case .travelDays: return "TRAVEL DAYS"
        case .worldPercent: return "OF THE WORLD"
        case .longestTripBeaten: return "DAYS — LONGEST TRIP YET"
        }
    }

    private var subline: String {
        switch moment.milestone {
        case .countryCount(let n):
            return "That's \(n) countries in your lifetime log."
        case .travelDays(let n):
            return "\(n) days of your life on the road."
        case .worldPercent:
            return "\(moment.countries) countries — the map is filling in."
        case .longestTripBeaten:
            return "Your longest stretch away from home, ever."
        }
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

private struct MilestoneSlamHaptic: ViewModifier {
    let fired: Bool

    func body(content: Content) -> some View {
        content.onChange(of: fired) { _, now in
            if now { HapticsDirector.shared.stampSlam() }
        }
    }
}
