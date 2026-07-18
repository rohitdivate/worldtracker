import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Theme.sky.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Version 0.1 · Milestone 0")
                            .foregroundStyle(Theme.ink2)
                    } icon: {
                        Image(systemName: "hammer.fill")
                            .foregroundStyle(Theme.aurora1)
                    }
                    .font(.system(size: 14))

                    Label {
                        Text("Everything stays on this device")
                            .foregroundStyle(Theme.ink2)
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Theme.aurora1)
                    }
                    .font(.system(size: 14))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .nightCard()

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
