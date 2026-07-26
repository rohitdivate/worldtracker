import SwiftUI

/// The little aurora globe — the app's mascot mark, used in onboarding,
/// Wrapped, and share-card branding.
struct MiniGlobe: View {
    var size: CGFloat = 130
    var showsPlane = true

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Theme.aurora1,
                        Theme.globeOcean,
                        Theme.card,
                    ],
                    center: .init(x: 0.32, y: 0.28),
                    startRadius: size * 0.05,
                    endRadius: size * 0.92
                )
            )
            .frame(width: size, height: size)
            .shadow(color: Theme.aurora1.opacity(0.45), radius: size * 0.3)
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
