import SwiftUI
import WorldTrackerKit

/// First-launch priming: earn trust, then ask for When-In-Use.
/// The Always upgrade is requested later, in context, after tracking has
/// proven itself — the pattern Apple rewards with a higher grant rate.
struct WelcomeFlow: View {
    @Environment(LocationService.self) private var location
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var step = 0
    @State private var tzCountry: String?
    @State private var showHomePicker = false

    var body: some View {
        ZStack {
            AuroraBackground()

            switch step {
            case 0: welcome
            case 1: permission
            case 2: homeStep
            case 3: photoOffer
            default: photoProgress
            }
        }
        .sheet(isPresented: $showHomePicker) {
            CountryPickerView { code in pickHome(code) }
        }
        .task {
            let lookup = try? await AppContainer.shared.geoProvider.lookup()
            tzCountry = lookup?.countryCode(forTimeZoneID: TimeZone.current.identifier)
        }
    }

    private var engine: PhotoBackfillEngine { AppContainer.shared.backfillEngine }

    /// Every exit path funnels through here so the completion timestamp is
    /// always recorded (the Always-upgrade gate keys off it).
    private func finishOnboarding() {
        UserDefaults.standard.set(Date(), forKey: "onboardingCompletedAt")
        UserDefaults.standard.set(
            AppContainer.shared.ledgerStore.todayEpoch, forKey: "onboardingCompletedDay"
        )
        onboardingDone = true
    }

    private func pickHome(_ code: String) {
        AppContainer.shared.ledgerStore.homeTimeline = .single(code)
        withAnimation(.spring(duration: 0.45)) { step = 3 }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            globe
            Text("Your journey,\nremembered.")
                .font(Theme.display(34, weight: .heavy))
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
                .font(Theme.display(30, weight: .heavy))
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
            Text("iOS asks for “While Using” first — later, one more tap turns on full background logging.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
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

    /// Home base — without it every day would count as travel.
    private var homeStep: some View {
        let deviceRegion = Locale.current.region?.identifier
        var chips: [String] = []
        if let deviceRegion { chips.append(deviceRegion) }
        if let tzCountry, !chips.contains(tzCountry) { chips.append(tzCountry) }

        return VStack(spacing: 16) {
            Spacer()
            Text("🏠").font(.system(size: 44))
            Text("Where do you live?")
                .font(Theme.display(28, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Days at home don't count as travel — this keeps every stat honest. Moved between countries before? You can add your full home history later in Settings.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
            Spacer()

            VStack(spacing: 10) {
                ForEach(chips, id: \.self) { code in
                    Button {
                        pickHome(code)
                    } label: {
                        HStack(spacing: 10) {
                            Text(flagEmoji(code)).font(.system(size: 24))
                            Text(countryName(code))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.aurora1)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .nightCard()
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showHomePicker = true
                } label: {
                    Text("Somewhere else…")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.aurora1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .nightCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Button("I'll set this later") {
                withAnimation(.spring(duration: 0.45)) { step = 3 }
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
                .font(Theme.display(30, weight: .heavy))
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
                withAnimation(.spring(duration: 0.45)) { step = 4 }
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
                finishOnboarding()
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
            if case .done(let days, let photos, let countries) = engine.progress.stage {
                VStack(spacing: 10) {
                    if days == 0 && photos > 0 {
                        Text("None of your \(photos.formatted()) photos carry location data — you can import Google Timeline anytime in Settings → Import.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink2)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("✨ \(days) travel days · \(countries) countries — reconstructed from \(photos.formatted()) photos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        finishOnboarding()
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
            } else if case .denied = engine.progress.stage {
                VStack(spacing: 10) {
                    Text("Photo access is off. You can turn it on in iOS Settings and re-run the scan from Settings → Time Machine.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Open iOS Settings") {
                        openSystemSettings()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.aurora1)
                    Button("Continue anyway") {
                        finishOnboarding()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                }
                .padding(.bottom, 26)
            } else if case .failed = engine.progress.stage {
                Button("Continue anyway") {
                    finishOnboarding()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .padding(.bottom, 26)
            } else {
                Button("Continue in the background") {
                    finishOnboarding()
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
