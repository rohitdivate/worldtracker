import SwiftUI

/// The animated aurora that gives the app its identity.
/// A slowly drifting mesh gradient in the Night Flight palette; colors can be
/// tinted toward the current country's "mood" color later.
struct AuroraBackground: View {
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                mesh(phase: 0.6)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    mesh(phase: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func mesh(phase: TimeInterval) -> some View {
        let t = phase * 0.12
        let x1 = Float(0.35 + 0.12 * sin(t))
        let y1 = Float(0.28 + 0.10 * cos(t * 0.8))
        let x2 = Float(0.72 + 0.10 * sin(t * 0.7 + 2))
        let y2 = Float(0.55 + 0.12 * cos(t * 0.9 + 1))

        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [x1, y1], [1, 0.5],
                [0, 1], [x2, y2], [1, 1],
            ],
            colors: [
                Theme.sky, Theme.skyRaised, Theme.sky,
                Theme.skyRaised,
                Theme.aurora1.opacity(0.32 * intensity),
                Theme.aurora2.opacity(0.30 * intensity),
                Theme.sky, Theme.skyRaised, Theme.sky,
            ]
        )
    }
}

#Preview {
    AuroraBackground()
}
