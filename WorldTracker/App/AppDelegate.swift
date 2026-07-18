import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Build the full stack immediately — when iOS relaunches us in the
        // background for a significant location change
        // (launchOptions[.location]), monitoring must be restarted within
        // this call or the event stream dies.
        let container = AppContainer.shared
        container.locationService.startMonitoring()

        if launchOptions?[.location] != nil {
            // Relaunched by a location event: the delegate callback with the
            // triggering location follows automatically now that the manager
            // exists and monitoring is restarted.
        }
        return true
    }
}
