import SwiftUI

/// First-launch priming: earn trust, then ask for When-In-Use.
/// The Always upgrade is requested later, in context, after tracking has
/// proven itself — the pattern Apple rewards with a higher grant rate.
struct WelcomeFlow: View {
    @Environment(LocationService.self) private var location
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var step = 0

    var body: some View {
        ZStack {
            AuroraBackground()

            switch step {
            case 0: welcome
            default: permission
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            globe
            Text("Your journey,\nremembered.")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Been There quietly notices which country you wake up in. No accounts. No servers. Nothing leaves this phone.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.45)) { step = 1 }
            } label: {
                Text("Get started")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .transition(.opacity)
    }

    private var permission: some View {
        VStack(spacing: 14) {
            Spacer()
            globe
            Text("Let it write itself")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            VStack(spacing: 10) {
                promise(icon: "lock.fill", title: "Private by design",
                        detail: "Your location history never leaves your device")
                promise(icon: "battery.100percent", title: "Invisible to your battery",
                        detail: "Cell-tower wake-ups, never continuous GPS")
                promise(icon: "airplane", title: "Works offline",
                        detail: "Borders are detected on-device, even after airplane mode")
            }
            .padding(.horizontal, 24)
            Spacer()
            Button {
                location.requestWhenInUse()
                onboardingDone = true
            } label: {
                Text("Enable location")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            Button("Maybe later") {
                onboardingDone = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink2)
            .padding(.bottom, 26)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var globe: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.aurora1, Color(red: 0.18, green: 0.56, blue: 0.72), Theme.card],
                    center: .init(x: 0.32, y: 0.28),
                    startRadius: 6,
                    endRadius: 120
                )
            )
            .frame(width: 130, height: 130)
            .shadow(color: Theme.aurora1.opacity(0.45), radius: 40)
            .overlay(alignment: .topTrailing) {
                Text("✈️").font(.system(size: 24)).offset(x: 6, y: -2)
            }
    }

    private func promise(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.auroraGradient)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .nightCard()
    }
}
