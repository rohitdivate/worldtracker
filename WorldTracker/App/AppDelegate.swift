import UIKit
import UserNotifications

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

        UNUserNotificationCenter.current().delegate = self

        if launchOptions?[.location] != nil {
            // Relaunched by a location event: the delegate callback with the
            // triggering location follows automatically now that the manager
            // exists and monitoring is restarted.
        }
        return true
    }
}

extension Notification.Name {
    /// Posted when a notification tap should switch tabs; userInfo["tab"]
    /// carries the same host strings as the beenthere:// widget links.
    static let openTabDeepLink = Notification.Name("beenthere.openTab")
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Notification taps: "wrapped" → straight into the story, anything else
    /// ("map", "calendar", …) → switch to that tab.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let link = info["deeplink"] as? String else { return }
        await MainActor.run {
            if link == "wrapped" {
                NotificationCenter.default.post(name: .openWrapped, object: nil)
            } else {
                NotificationCenter.default.post(
                    name: .openTabDeepLink, object: nil, userInfo: ["tab": link]
                )
            }
        }
    }
}
