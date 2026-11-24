import SwiftUI
import WorldTrackerKit

/// The little aurora globe — the app's mascot mark, used in onboarding,
/// Wrapped, and share-card branding.
struct MiniGlobe: View {
    var size: CGFloat = 130
    var showsPlane = true
    /// Defaults to the app skin. The always-dark story pages pass
    /// `Story.palette`: on a light skin the app's ink ball vanishes there.
    var palette: ThemePalette = Theme.palette

    /// On a dark page the ball is the light ink; on a light one, the dark.
    private var ball: Color {
        palette.isLight ? palette.globeOcean.color : palette.ink.color.mix(with: palette.sky.color, by: 0.25)
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    // Bold skins: a matte ink ball, lit from the top left.
                    colors: palette.isBold
                        ? [ball.mix(with: palette.ink.color, by: 0.35), ball, ball.mix(with: .black, by: 0.25)]
                        : [palette.aurora1.color, palette.globeOcean.color, palette.card.color],
                    center: .init(x: 0.32, y: 0.28),
                    startRadius: size * 0.05,
                    endRadius: size * 0.92
                )
            )
            .frame(width: size, height: size)
            .shadow(
                color: palette.isBold ? Color.black.opacity(0.22) : palette.aurora1.color.opacity(0.45),
                radius: size * (palette.isBold ? 0.12 : 0.3),
                y: palette.isBold ? size * 0.08 : 0
            )
            .overlay(alignment: .topTrailing) {
                if showsPlane {
                    Text("✈️")
                        .font(.system(size: size * 0.18))
                        .offset(x: size * 0.05, y: -size * 0.02)
                }
            }
    }
}

#Preview {
    MiniGlobe()
        .padding(60)
        .background(Theme.sky)
}
