import ActivityKit
import Foundation
import WorldTrackerKit

/// Starts a Live Activity when you're abroad, keeps its counters honest on
/// every ledger change and wake, ends it on a full home day. iOS's activity
/// time limits mean it can be dismissed while we're backgrounded — the next
/// sync (any location wake or foreground) simply starts it again.
@MainActor
enum TravelLiveActivityManager {
    /// User master switch (Settings → "Trip banner"). Absent = on.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
    }

    static func sync(store: LedgerStore) {
        guard isEnabled else {
            endAll()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let stay = store.currentStay()
        let home = store.homeCountry

        guard let stay, stay.countryCode != home else {
            // Home (or nowhere yet): the trip banner has nothing to say.
            endAll()
            return
        }

        let today = store.todayEpoch
        let (year, _, _) = EpochDay(value: today).civil()
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let stats = store.stats(in: jan1...today)

        let state = TravelActivityAttributes.ContentState(
            dayOfStay: stay.days,
            daysThisYear: store.daysThisYear(in: stay.countryCode),
            countriesThisYear: stats.countriesVisited
        )
        let content = ActivityContent(state: state, staleDate: nextMidnight())

        // Only a genuinely LIVE activity can be updated in place. A banner
        // the user swiped away lingers in .activities as .dismissed —
        // updating it is invisible, which would strand the feature forever.
        let all = Activity<TravelActivityAttributes>.activities
        let live = all.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        let dead = all.filter {
            $0.activityState != .active && $0.activityState != .stale
        }
        Task {
            for activity in dead {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        if let activity = live.first(where: { $0.attributes.countryCode == stay.countryCode }) {
            Task { await activity.update(content) }
        } else {
            // A border hop retires the previous country's banner.
            Task {
                for activity in live {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            let attributes = TravelActivityAttributes(countryCode: stay.countryCode)
            _ = try? Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }
    }

    static func endAll() {
        Task {
            for activity in Activity<TravelActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .default)
            }
        }
    }

    private static func nextMidnight() -> Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60 + 60)
    }
}
