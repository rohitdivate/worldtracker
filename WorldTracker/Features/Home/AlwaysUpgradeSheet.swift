import SwiftUI
import UIKit

/// Opens the app's page in iOS Settings — the fallback once the one-shot
/// system permission prompt has been spent.
@MainActor
func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}

/// One place that owns when and how the Always-authorization upgrade is
/// offered. iOS shows the system upgrade dialog ONCE per install — the gate
/// tracks when it's spent so every later CTA routes to Settings instead.
@MainActor
enum AlwaysPromptGate {
    static var systemPromptUsed: Bool {
        UserDefaults.standard.bool(forKey: "alwaysSystemPromptUsed")
    }

    static func markSystemPromptUsed() {
        UserDefaults.standard.set(true, forKey: "alwaysSystemPromptUsed")
    }

    private static var shownCount: Int {
        UserDefaults.standard.integer(forKey: "alwaysPromptShownCount")
    }

    private static var lastShownAt: Date? {
        UserDefaults.standard.object(forKey: "alwaysPromptLastShownAt") as? Date
    }

    static func recordShown() {
        UserDefaults.standard.set(shownCount + 1, forKey: "alwaysPromptShownCount")
        UserDefaults.standard.set(Date(), forKey: "alwaysPromptLastShownAt")
    }

    /// All conditions for proactively offering the sheet (Home, on-active).
    static func shouldOffer() async -> Bool {
        let container = AppContainer.shared
        let location = container.locationService

        guard UserDefaults.standard.bool(forKey: "onboardingDone"),
              location.smartTrackingEnabled,
              location.authorizationStatus == .authorizedWhenInUse,
              shownCount < 2,
              container.celebrationCoordinator.current == nil,
              !container.backfillEngine.progress.isRunning,
              !container.importEngine.timelineProgress.isRunning,
              !container.importEngine.flightProgress.isRunning
        else { return false }

        if let last = lastShownAt, Date().timeIntervalSince(last) < 7 * 86_400 {
            return false
        }

        // Never on onboarding day — let tracking prove itself first.
        let store = container.ledgerStore
        let completedDay = UserDefaults.standard.integer(forKey: "onboardingCompletedDay")
        guard completedDay > 0, store.todayEpoch > completedDay else { return false }

        // Evidence it's worth asking: a sample recorded, or a full day passed.
        let sampleCount = await container.ingestor.stats().totalSamples
        if sampleCount >= 1 { return true }
        if let completedAt = UserDefaults.standard.object(forKey: "onboardingCompletedAt") as? Date {
            return Date().timeIntervalSince(completedAt) >= 24 * 3600
        }
        return false
    }
}

/// The in-context pitch for background tracking — shown once tracking has
/// had a chance to prove itself, never more than twice, a week apart.
struct AlwaysUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.7).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                MiniGlobe(size: 84)
                Text("Let it log while\nyou sleep")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("Right now Been There only logs while the app is open. One more permission lets iOS wake it quietly when you change cities or countries — that's the whole magic.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 310)
                VStack(spacing: 10) {
                    benefit(icon: "battery.100percent", text: "Still battery-invisible — cell-tower wake-ups, never GPS")
                    benefit(icon: "lock.fill", text: "Still private — everything stays on this phone")
                }
                .padding(.horizontal, 26)
                Spacer()

                Button {
                    if AlwaysPromptGate.systemPromptUsed {
                        openSystemSettings()
                    } else {
                        AlwaysPromptGate.markSystemPromptUsed()
                        location.requestAlwaysUpgrade()
                    }
                    dismiss()
                } label: {
                    Text(AlwaysPromptGate.systemPromptUsed
                         ? "Open iOS Settings"
                         : "Turn on background logging")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.sky)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Button("Not now") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .padding(.bottom, 24)
            }
            .padding(.top, 30)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.sky)
    }

    private func benefit(icon: String, text: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.auroraGradient)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
            Spacer()
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 13)
        .nightCard()
    }
}

/// Compact "tracking limited" indicator for Home — visible while the app can
/// only log in the foreground (or not at all).
struct TrackingStatusPill: View {
    let status: TrackingLimitation
    let onTap: () -> Void

    enum TrackingLimitation {
        case whileUsingOnly
        case off
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: status == .off ? "location.slash.fill" : "moon.zzz.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(status == .off
                     ? "Tracking is off — fix"
                     : "Logs only while open — fix")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(Theme.amber)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Theme.card)
                    .overlay(Capsule().strokeBorder(Theme.amber.opacity(0.4), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
