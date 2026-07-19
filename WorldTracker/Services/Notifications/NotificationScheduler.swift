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

    /// Per-notification toggles, default ON until the user flips one.
    private func enabled(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
    }

    /// Called when a Settings toggle flips ON: upgrade provisional delivery
    /// to the full banner+sound grant (the user explicitly asked for these).
    func requestFullAuthorization() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    /// "Welcome home — 8 days in Spain." Fires from the milestone tracker's
    /// settled-ledger pass on the first full home day after a real trip.
    func maybeScheduleTripRecap(store: LedgerStore) {
        guard enabled("notifyTripRecap") else { return }
        let today = store.todayEpoch
        guard let home = store.homeTimeline.home(on: today),
              store.resolvedDays(in: today...today).first?.countryCodes.first == home
        else { return }

        let earliest = min(store.earliestDay ?? today, today)
        guard let ended = store.tripSegments(in: earliest...today)
            .filter({ $0.endDay >= today - 2 && $0.endDay < today && $0.dayCount >= 2 })
            .max(by: { $0.endDay < $1.endDay })
        else { return }

        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "lastTripRecapStretchStart") != ended.startDay else { return }
        defaults.set(ended.startDay, forKey: "lastTripRecapStretchStart")

        Task {
            let center = UNUserNotificationCenter.current()
            guard await ensureAuthorized(center) else { return }

            let content = UNMutableNotificationContent()
            content.title = "Welcome home 👋"
            content.body = "\(ended.dayCount) days in \(countryName(ended.countryCode)) — your trip is on the map."
            content.sound = .default
            content.userInfo = ["deeplink": "calendar"]

            // +2h so it lands after the unpacking, not during the commute.
            try? await center.add(
                UNNotificationRequest(
                    identifier: "trip-recap-\(ended.startDay)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: false)
                )
            )
        }
    }

    /// First days of a month: last month's numbers, skipped entirely for
    /// no-travel months. Idempotent per month via a UserDefaults latch.
    func maybeScheduleMonthlyRecap(store: LedgerStore) {
        guard enabled("notifyMonthlyRecap") else { return }
        let today = store.todayEpoch
        let (year, month, day) = EpochDay(value: today).civil()
        guard (1...3).contains(day) else { return }

        let prevYear = month == 1 ? year - 1 : year
        let prevMonth = month == 1 ? 12 : month - 1
        let latch = "monthly-recap-\(prevYear)-\(prevMonth)"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: latch) else { return }
        defaults.set(true, forKey: latch)

        let first = EpochDay.daysFromCivil(year: prevYear, month: prevMonth, day: 1)
        let last = EpochDay.daysFromCivil(year: year, month: month, day: 1) - 1
        let stats = store.stats(in: first...last)
        guard stats.travelDays > 0 else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            guard await ensureAuthorized(center) else { return }

            let monthName = DateFormatter().monthSymbols[prevMonth - 1]
            let content = UNMutableNotificationContent()
            content.title = "Your \(monthName), mapped"
            content.body = stats.countriesVisited == 1
                ? "\(stats.travelDays) travel \(stats.travelDays == 1 ? "day" : "days") last month. See the flags on your calendar."
                : "\(stats.travelDays) travel days across \(stats.countriesVisited) countries last month."
            content.sound = .default
            content.userInfo = ["deeplink": "calendar"]

            var when = DateComponents()
            when.hour = 10
            try? await center.add(
                UNNotificationRequest(
                    identifier: latch,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                )
            )
        }
    }

    /// December: one teaser ahead of the Jan-1 reveal, only for a year with
    /// enough data to build a story.
    func maybeScheduleWrappedTeaser(store: LedgerStore, builder: YearInReviewBuilder) {
        guard enabled("notifyWrappedTeaser") else { return }
        let (year, month, _) = EpochDay(value: store.todayEpoch).civil()
        guard month == 12, builder.availableYears().contains(year) else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            guard await ensureAuthorized(center) else { return }

            let content = UNMutableNotificationContent()
            content.title = "Your \(year) is almost wrapped ✨"
            content.body = "The countries, the stamps, the map you lit up — the full story unlocks January 1."
            content.sound = .default
            content.userInfo = ["deeplink": "wrapped"]

            var when = DateComponents()
            when.year = year
            when.month = 12
            when.day = 26
            when.hour = 9
            try? await center.add(
                UNNotificationRequest(
                    identifier: "wrapped-teaser-\(year)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                )
            )
        }
    }

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
