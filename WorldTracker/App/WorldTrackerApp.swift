import SwiftData
import SwiftUI

@main
struct WorldTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .tint(Theme.aurora2)
                .environment(AppContainer.shared.locationService)
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
