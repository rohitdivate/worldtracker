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

    /// Provisional-auth dance shared by every notification: silently
    /// authorized, never a dialog. Returns false when delivery is impossible.
    private func ensureAuthorized(_ center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(
                options: [.alert, .sound, .provisional]
            )) ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    /// A backgrounded Time Machine scan finished — land the payoff.
    /// Gated by "notifyBackfillDone" (default on).
    func notifyBackfillComplete(days: Int, countries: Int) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "notifyBackfillDone") != nil,
           !defaults.bool(forKey: "notifyBackfillDone") { return }
        guard days > 0 else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            guard await ensureAuthorized(center) else { return }

            let content = UNMutableNotificationContent()
            content.title = "Your history is rebuilt ✨"
            content.body = countries == 1
                ? "\(days) travel days reconstructed — your map is ready."
                : "\(days) travel days across \(countries) countries — your map is lit."
            content.sound = .default
            content.userInfo = ["deeplink": "map"]

            try? await center.add(
                UNNotificationRequest(
                    identifier: "backfill-done",
                    content: content,
                    trigger: nil
                )
            )
        }
    }

    /// Idempotent: same identifier replaces any previous request.
    func scheduleWrappedReveal() {
        Task {
            let center = UNUserNotificationCenter.current()
            guard await ensureAuthorized(center) else { return }

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
