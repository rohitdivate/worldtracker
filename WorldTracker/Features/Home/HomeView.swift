import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 20) {
                Spacer()

                Text("🌍")
                    .font(.system(size: 56))

                Text("Been There")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text("A private atlas of everywhere you've ever been. It writes itself.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)

                Spacer()

                VStack(spacing: 8) {
                    Text("MILESTONE 0")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.aurora1)
                    Text("The shell is up. Tracking, calendar, map, places and the photo Time Machine land in the next updates.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .nightCard()
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
