import Foundation
import Observation
import WorldTrackerKit

/// The user's day-count rules. Rules are settings, not ledger facts, so they
/// live in UserDefaults as one Codable blob (the same pattern as the home
/// timeline) and every number shown for them is computed from the ledger at
/// read time by the Kit's `DayLimitEvaluator`.
@MainActor
@Observable
final class DayLimitStore {
    private static let key = "dayLimitRules"

    private(set) var rules: [DayLimitRule]

    @ObservationIgnored private var cacheKey = ""
    @ObservationIgnored private var cache: [DayLimitStatus] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([DayLimitRule].self, from: data) {
            rules = decoded
        } else {
            rules = []
        }
    }

    // MARK: - Mutations

    func add(_ rule: DayLimitRule) {
        rules.append(rule)
        persist()
    }

    func update(_ rule: DayLimitRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            add(rule)
            return
        }
        rules[index] = rule
        persist()
    }

    func remove(id: String) {
        rules.removeAll { $0.id == id }
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: Self.key)
        cacheKey = ""
        // Widgets, the Live Activity and limit alerts all read rule status.
        let ledger = AppContainer.shared.ledgerStore
        SharedSnapshotStore.write(from: ledger)
        NotificationScheduler.shared.maybeScheduleLimitAlerts(statuses: statuses(using: ledger))
    }

    // MARK: - Evaluation

    /// One shared range for every rule, so the ledger resolves (and caches)
    /// the days once however many rules there are.
    func historyRange(today: Int) -> ClosedRange<Int> {
        let lookback = max(400, rules.map(\.window.lookbackDays).max() ?? 0)
        return (today - lookback)...today
    }

    func statuses(using store: LedgerStore) -> [DayLimitStatus] {
        let today = store.todayEpoch
        let key = "\(store.changeToken)-\(today)-\(rules.hashValue)"
        if key == cacheKey { return cache }
        let days = store.resolvedDays(in: historyRange(today: today))
        cache = rules.map { DayLimitEvaluator.evaluate(rule: $0, days: days, asOf: today) }
        cacheKey = key
        return cache
    }

    func status(id: String, using store: LedgerStore) -> DayLimitStatus? {
        statuses(using: store).first { $0.id == id }
    }

    /// The rule the current country is on the clock for, most pressing first.
    /// Feeds the Home hero and the Live Activity.
    func activeStatus(using store: LedgerStore) -> DayLimitStatus? {
        statuses(using: store)
            .filter { $0.countsToday && $0.rule.goal == .stayUnder }
            .max { $0.fraction < $1.fraction }
    }

    /// Longest stay starting on `entryDay` under a rule.
    func maxStay(rule: DayLimitRule, entryDay: Int, using store: LedgerStore) -> Int? {
        let today = store.todayEpoch
        return DayLimitEvaluator.maxStay(
            rule: rule,
            days: store.resolvedDays(in: historyRange(today: today)),
            asOf: today,
            entryDay: entryDay
        )
    }

    // MARK: - Analysis

    /// Every resolved day on record: peaks and past windows look further
    /// back than a single evaluation needs to.
    private func allDays(using store: LedgerStore) -> [ResolvedDay] {
        let today = store.todayEpoch
        return store.resolvedDays(in: min(store.earliestDay ?? today, today)...today)
    }

    /// Where the rule ends up if every planned trip happens. Nil with no
    /// plans.
    func forecast(for rule: DayLimitRule, using store: LedgerStore) -> DayLimitForecast? {
        let today = store.todayEpoch
        let planned = AppContainer.shared.planStore.projectedDays(using: store)
        guard !planned.isEmpty else { return nil }
        guard let forecast = DayLimitEvaluator.forecast(
            rule: rule,
            days: store.resolvedDays(in: historyRange(today: today)),
            planned: planned,
            asOf: today
        ) else { return nil }
        // Plans that never touch this rule aren't worth a line: the count
        // only falls from here.
        let usedToday = status(id: rule.id, using: store)?.used ?? 0
        if forecast.peakUsed <= usedToday && forecast.crossingDay == nil { return nil }
        return forecast
    }

    func peak(for rule: DayLimitRule, using store: LedgerStore) -> DayLimitPeak? {
        DayLimitEvaluator.peak(rule: rule, days: allDays(using: store), asOf: store.todayEpoch)
    }

    func pastWindows(for rule: DayLimitRule, using store: LedgerStore) -> [DayLimitWindowTotal] {
        DayLimitEvaluator.pastWindows(rule: rule, days: allDays(using: store), asOf: store.todayEpoch)
    }

    /// The whole history of a rule as line items, for the report.
    func stretches(for rule: DayLimitRule, using store: LedgerStore) -> [CountedStretch] {
        let today = store.todayEpoch
        return DayLimitEvaluator.stretches(
            rule: rule, days: allDays(using: store),
            in: min(store.earliestDay ?? today, today)...today
        )
    }

    // MARK: - Suggestions

    /// Presets worth offering: Schengen always; the UK pair for someone who
    /// lives there; a calendar-year 183-day count for any other home.
    func suggestions(home: String?) -> [DayLimitRule] {
        var result: [DayLimitRule] = [.schengen()]
        if home == "GB" {
            result.append(.ukAbsences())
            result.append(.ukTaxYear())
        }
        // The UK counts residence over its tax year, which the preset above
        // already covers; a calendar-year twin would only be a near-duplicate.
        if let home, home != "GB" {
            result.append(.calendarYear183(country: home, countryName: countryNameInSentence(home)))
        }
        let existing = Set(rules.map { RuleShape($0) })
        return result.filter { !existing.contains(RuleShape($0)) }
    }

    /// Identity ignoring id and name: two rules that count the same thing.
    private struct RuleShape: Hashable {
        let scope: DayLimitScope
        let window: DayLimitWindow
        let limit: Int

        init(_ rule: DayLimitRule) {
            scope = rule.scope
            window = rule.window
            limit = rule.limit
        }
    }
}
