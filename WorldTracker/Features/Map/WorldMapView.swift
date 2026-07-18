import SwiftUI

struct WorldMapView: View {
    var body: some View {
        ComingSoonScreen(
            title: "Your world",
            systemImage: "globe.europe.africa.fill",
            message: "A globe that remembers your flight paths, with every visited country lit up."
        )
    }
}

#Preview {
    WorldMapView()
        .preferredColorScheme(.dark)
}
