import SwiftUI

/// Deterministic 0…1 noise from an index — particles land identically on
/// every render, so previews, re-renders, and video export frames all agree.
private func noise01(_ index: Int, _ salt: Int) -> Double {
    var h = UInt64(bitPattern: Int64(index &* 2_654_435_761 &+ salt &* 40_503))
    h ^= h >> 33
    h = h &* 0xFF51_AFD7_ED55_8CCD
    h ^= h >> 33
    return Double(h % 10_000) / 10_000
}

/// One-shot radial burst in the aurora palette. Drive `progress` 0→1;
/// outside that window it draws nothing.
struct AuroraBurstView: View {
    var progress: Double
    var particleCount: Int = 72

    var body: some View {
        Canvas { context, size in
            guard progress > 0, progress < 1 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let reach = min(size.width, size.height) * 0.52
            let eased = 1 - pow(1 - progress, 3)

            for i in 0..<particleCount {
                let angle = noise01(i, 1) * 2 * .pi
                let speed = 0.35 + 0.65 * noise01(i, 2)
                let distance = eased * speed * reach
                let radius = 1.2 + 2.6 * noise01(i, 3)
                let fade = (1 - progress) * (0.5 + 0.5 * noise01(i, 4))
                // A touch of gravity so the burst falls like embers.
                let droop = eased * eased * 26 * noise01(i, 5)

                let position = CGPoint(
                    x: center.x + cos(angle) * distance,
                    y: center.y + sin(angle) * distance + droop
                )
                let color: Color = switch i % 5 {
                case 0, 1: Theme.aurora1
                case 2, 3: Theme.aurora2
                default: Theme.amber
                }
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: position.x - radius, y: position.y - radius,
                        width: radius * 2, height: radius * 2
                    )),
                    with: .color(color.opacity(fade))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Ambient drifting dust — the quiet sparkle behind hero pages.
struct ParticleField: View {
    var particleCount: Int = 34
    var opacity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                field(at: 40)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    field(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func field(at time: TimeInterval) -> some View {
        Canvas { context, size in
            for i in 0..<particleCount {
                let phase = time * (0.05 + 0.06 * noise01(i, 6)) + noise01(i, 7) * 10
                let x = (noise01(i, 8) + 0.04 * sin(phase * 2)).truncatingRemainder(dividingBy: 1)
                let y = (noise01(i, 9) - phase * 0.02).truncatingRemainder(dividingBy: 1)
                let yy = y < 0 ? y + 1 : y
                let radius = 0.7 + 1.5 * noise01(i, 10)
                let twinkle = 0.25 + 0.55 * (0.5 + 0.5 * sin(phase * 3))

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x * size.width - radius,
                        y: yy * size.height - radius,
                        width: radius * 2, height: radius * 2
                    )),
                    with: .color(
                        (i % 3 == 0 ? Theme.aurora2 : Theme.aurora1)
                            .opacity(twinkle * opacity)
                    )
                )
            }
        }
    }
}
