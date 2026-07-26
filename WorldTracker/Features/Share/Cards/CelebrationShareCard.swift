import SwiftUI
import WorldTrackerKit

/// The COUNTRY #N stamp card — the single most shareable moment in the app,
/// frozen as a 4:5 postcard.
struct CelebrationShareCard: View {
    let code: String
    let number: Int
    let dateText: String

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 12) {
                Spacer()

                FlagChip(code: code, size: 104)
                    .shadow(color: Theme.aurora1.opacity(0.5), radius: 26)

                Text("COUNTRY #\(number)")
                    .font(Theme.numeric(15, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 10)

                Text(countryName(code))
                    .font(Theme.display(33, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(dateText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.ink3)

                Spacer()

                ShareWordmark(withHook: true)
                    .padding(.bottom, 26)
            }
        }
        .frame(width: 360, height: 450)
    }
}

#Preview {
    CelebrationShareCard(code: "JP", number: 14, dateText: "18 July 2026")
}
