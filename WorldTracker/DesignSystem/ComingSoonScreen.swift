import SwiftUI

/// Themed placeholder used while a tab's real feature lands in a later milestone.
struct ComingSoonScreen: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.5)

            VStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.auroraGradient)
                    .symbolEffect(.breathe)

                Text(title)
                    .font(Theme.display(30, weight: .heavy))
                    .foregroundStyle(Theme.ink)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(28)
        }
    }
}

#Preview {
    ComingSoonScreen(
        title: "Places",
        systemImage: "mappin.and.ellipse",
        message: "The shops, parks and museums you visit will collect here."
    )
    .preferredColorScheme(.dark)
}
