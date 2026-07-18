import SwiftUI

struct PlacesListView: View {
    var body: some View {
        ComingSoonScreen(
            title: "Places",
            systemImage: "mappin.and.ellipse",
            message: "Not just countries — the market, the museum, the park. They'll collect here."
        )
    }
}

#Preview {
    PlacesListView()
        .preferredColorScheme(.dark)
}
