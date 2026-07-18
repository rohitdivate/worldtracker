import SwiftUI

struct HistoryView: View {
    var body: some View {
        ComingSoonScreen(
            title: "Calendar",
            systemImage: "calendar",
            message: "Every day will wear the flag of where you were — split flags on border days."
        )
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
