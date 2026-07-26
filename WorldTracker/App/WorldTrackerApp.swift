import SwiftData
import SwiftUI
import WorldTrackerKit

@main
struct WorldTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// Drives the re-render on theme change. `Theme`'s tokens are static, so
    /// SwiftUI has nothing to observe — keying the root on this id is what
    /// makes a switch take effect.
    @AppStorage(ThemeStore.key) private var themeID = ThemeID.default.rawValue

    private var palette: ThemePalette { ThemeID(storedValue: themeID).palette }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                // Light themes need the system chrome to follow, or the status
                // bar stays white-on-cream.
                .preferredColorScheme(palette.isLight ? .light : .dark)
                .tint(palette.aurora2.color)
                .environment(AppContainer.shared.locationService)
                .id(themeID)
                .task(id: themeID) {
                    // @AppStorage can write before ThemeStore is consulted
                    // (e.g. an iCloud-restored value at launch), so re-sync the
                    // static palette from whatever the store actually holds.
                    ThemeStore.paletteDidChange(to: ThemeID(storedValue: themeID))
                }
        }
        .modelContainer(AppContainer.shared.modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppContainer.shared.locationService.onForeground()
                AppContainer.shared.placeNamer.processPending()
                SharedSnapshotStore.write(from: AppContainer.shared.ledgerStore)
                if UserDefaults.standard.bool(forKey: "onboardingDone") {
                    // All idempotent: same ids replace, latches skip.
                    NotificationScheduler.shared.scheduleWrappedReveal()
                    NotificationScheduler.shared.maybeScheduleMonthlyRecap(
                        store: AppContainer.shared.ledgerStore
                    )
                    NotificationScheduler.shared.maybeScheduleWrappedTeaser(
                        store: AppContainer.shared.ledgerStore,
                        builder: AppContainer.shared.wrappedBuilder
                    )
                }
            }
        }
    }
}
