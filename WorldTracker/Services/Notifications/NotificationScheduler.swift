import Foundation
import UserNotifications
import WorldTrackerKit

extension Notification.Name {
    /// Posted when the user taps the Wrapped reveal notification.
    static let openWrapped = Notification.Name("beenthere.openWrapped")
}

/// Local notifications only — one quiet knock a year.
/// Provisional authorization: the Jan-1 reveal arrives silently in
/// Notification Center without ever showing a permission dialog.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private init() {}

    /// Idempotent: same identifier replaces any previous request.
    func scheduleWrappedReveal() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(
                    options: [.alert, .sound, .provisional]
                )) ?? false
                guard granted else { return }
            case .denied:
                return
            default:
                break
            }

            let content = UNMutableNotificationContent()
            content.title = "Your Year in Travel is ready ✨"
            content.body = "Countries, stamps, and the map you lit up — open your story."
            content.sound = .default
            content.userInfo = ["deeplink": "wrapped"]

            var date = DateComponents()
            date.month = 1
            date.day = 1
            date.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

            try? await center.add(
                UNNotificationRequest(
                    identifier: "wrapped-reveal",
                    content: content,
                    trigger: trigger
                )
            )
        }
    }
}
