import Foundation
import WorldTrackerKit

/// Watches the ledger and turns lifetime-stat crossings into celebrations.
/// All detection is a pure snapshot diff (Kit MilestoneEngine); this class
/// owns timing, the seed rule, bulk collapse, and once-ever dedupe.
@MainActor
final class MilestoneTracker {
    private let store: LedgerStore
    private let celebration: CelebrationCoordinator
    private var debounce: Task<Void, Never>?

    private static let snapshotKey = "milestoneSnapshot"
    private static let awardedKey = "awardedMilestones"
    private static let longestStretchKey = "lastCelebratedLongestStretchStart"

    init(store: LedgerStore, celebration: CelebrationCoordinator) {
        self.store = store
        self.celebration = celebration
        NotificationCenter.default.addObserver(
            forName: .ledgerDidChange, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                AppContainer.shared.milestoneTracker.scheduleEvaluation()
            }
        }
    }

    /// Own debounce: bursts of ledger writes (a chunked backfill, a bulk
    /// import) evaluate once, after the dust settles.
    func scheduleEvaluation() {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    func evaluate() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "onboardingDone") else { return }
        // Mid-scan numbers are moving targets; completion posts
        // ledgerDidChange, so the settled state re-evaluates then.
        let container = AppContainer.shared
        if container.backfillEngine.progress.isRunning { return }
        if container.importEngine.timelineProgress.isRunning { return }
        if container.importEngine.flightProgress.isRunning { return }

        let (snapshot, longestSegment) = buildSnapshot()
        var awarded = Set(defaults.stringArray(forKey: Self.awardedKey) ?? [])

        guard let data = defaults.data(forKey: Self.snapshotKey),
              let before = try? JSONDecoder().decode(MilestoneSnapshot.self, from: data) else {
            // Seed rule: the first evaluation ever (which is also what a
            // first big backfill/import lands on) awards everything already
            // held, silently — no retro spam.
            for milestone in MilestoneEngine.crossed(before: .zero, after: snapshot) {
                awarded.insert(milestone.storageKey)
            }
            persist(snapshot: snapshot, awarded: awarded)
            return
        }

        var crossed = MilestoneEngine.crossed(before: before, after: snapshot)
            .filter { !awarded.contains($0.storageKey) }

        crossed = crossed.filter { milestone in
            guard case .longestTripBeaten(_, let startDay) = milestone else { return true }
            // Live trips only: once per stretch, and the stretch must still
            // be touching now — imported history never fires this.
            if defaults.integer(forKey: Self.longestStretchKey) == startDay { return false }
            guard let segment = longestSegment,
                  segment.startDay == startDay,
                  segment.endDay >= store.todayEpoch - 1 else { return false }
            return true
        }

        if let winner = crossed.first {
            // Bulk collapse: celebrate the highest-precedence crossing only;
            // the rest are marked awarded silently.
            for milestone in crossed { awarded.insert(milestone.storageKey) }
            if case .longestTripBeaten(_, let start) = winner {
                defaults.set(start, forKey: Self.longestStretchKey)
            }
            celebration.milestoneReached(
                winner, countries: snapshot.distinctCountries, flags: topFlags()
            )
        }
        persist(snapshot: snapshot, awarded: awarded)

        // The trip-ended recap rides the same settled-ledger pass.
        NotificationScheduler.shared.maybeScheduleTripRecap(store: store)
    }

    private func buildSnapshot() -> (MilestoneSnapshot, TripSegment?) {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let stats = store.stats(in: earliest...today)
        let longest = store.tripSegments(in: earliest...today).max {
            ($0.dayCount, $0.startDay) < ($1.dayCount, $1.startDay)
        }
        let snapshot = MilestoneSnapshot(
            distinctCountries: stats.countriesVisited,
            lifetimeTravelDays: stats.travelDays,
            longestTripDays: longest?.dayCount ?? 0,
            longestTripStartDay: longest?.startDay
        )
        return (snapshot, longest)
    }

    private func topFlags() -> [String] {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        return store.stats(in: earliest...today).daysPerCountry
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(9)
            .map(\.key)
    }

    private func persist(snapshot: MilestoneSnapshot, awarded: Set<String>) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.snapshotKey)
        }
        defaults.set(Array(awarded).sorted(), forKey: Self.awardedKey)
    }
}
