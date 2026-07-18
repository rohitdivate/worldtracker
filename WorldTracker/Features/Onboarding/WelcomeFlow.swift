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
            case 1: permission
            case 2: photoOffer
            default: photoProgress
            }
        }
    }

    private var engine: PhotoBackfillEngine { AppContainer.shared.backfillEngine }

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
                withAnimation(.spring(duration: 0.45)) { step = 2 }
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
                withAnimation(.spring(duration: 0.45)) { step = 2 }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink2)
            .padding(.bottom, 26)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var photoOffer: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.auroraGradient)
            Text("Where have you\nalready been?")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Your photo library remembers. Been There can read just the dates and locations of your photos — never the pictures — and rebuild years of travel history in about a minute.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
            Spacer()
            Button {
                engine.run()
                withAnimation(.spring(duration: 0.45)) { step = 3 }
            } label: {
                Text("Rebuild my history")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            Button("Skip — I'll do it later in Settings") {
                onboardingDone = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink2)
            .padding(.bottom, 26)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var photoProgress: some View {
        VStack(spacing: 16) {
            Spacer()
            TimeMachineProgressView(progress: engine.progress)
                .padding(.horizontal, 18)
            Spacer()
            if case .done(let days, let photos) = engine.progress.stage {
                VStack(spacing: 10) {
                    Text("✨ \(days) travel days reconstructed from \(photos.formatted()) photos")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Button {
                        onboardingDone = true
                    } label: {
                        Text("Show me my world")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.sky)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
            } else if case .failed = engine.progress.stage {
                Button("Continue anyway") {
                    onboardingDone = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .padding(.bottom, 26)
            } else {
                Button("Continue in the background") {
                    onboardingDone = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .padding(.bottom, 26)
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var globe: some View {
        MiniGlobe(size: 130)
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
