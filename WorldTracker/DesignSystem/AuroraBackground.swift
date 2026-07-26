import SwiftUI
import WorldTrackerKit

/// The animated aurora that gives the app its identity.
/// A slowly drifting mesh gradient in the active theme's palette; colors can be
/// tinted toward the current country's "mood" color later.
struct AuroraBackground: View {
    var intensity: Double = 1.0
    /// Pulls the aurora toward a mood color (Wrapped pages shift per scene).
    var tint: Color? = nil
    /// Override the palette. Defaults to the app theme, which is right for
    /// every ordinary screen; Wrapped passes `Story.palette` so its full-screen
    /// story stays dark even when the app theme is light — its white chrome and
    /// photo pages depend on a dark ground.
    var palette: ThemePalette = Theme.palette

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
                sky, skyRaised, sky,
                skyRaised,
                tinted(palette.aurora1.color).opacity(0.32 * intensity),
                tinted(palette.aurora2.color).opacity(0.30 * intensity),
                sky, skyRaised, sky,
            ]
        )
    }

    private var sky: Color { palette.sky.color }
    private var skyRaised: Color { palette.skyRaised.color }

    private func tinted(_ base: Color) -> Color {
        guard let tint else { return base }
        return base.mix(with: tint, by: 0.55)
    }
}

#Preview {
    AuroraBackground()
}
