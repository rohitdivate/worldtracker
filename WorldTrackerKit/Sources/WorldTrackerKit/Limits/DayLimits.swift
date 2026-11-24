import Foundation

/// The Schengen area, as the rolling 90/180 rule counts it. Bulgaria and
/// Romania joined in full in January 2025; Cyprus and Ireland are EU members
/// outside it.
public enum SchengenArea {
    public static let members: Set<String> = [
        "AT", "BE", "BG", "HR", "CZ", "DK", "EE", "FI", "FR", "DE",
        "GR", "HU", "IS", "IT", "LV", "LI", "LT", "LU", "MT", "NL",
        "NO", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "CH",
    ]
}

/// Which days a limit counts.
public enum DayLimitScope: Codable, Sendable, Equatable, Hashable {
    /// Any presence in this country (a border day counts, as it does for
    /// every immigration day count this is modelled on).
    case country(String)
    /// Any presence in any Schengen state.
    case schengen
    /// Whole days away: the day has a verdict and this country isn't in it.
    /// Departure and arrival days touch the country, so they don't count,
    /// which is how the UK counts absences.
    case outside(String)

    public func counts(_ codes: [String]) -> Bool {
        switch self {
        case .country(let code):
            return codes.contains(code)
        case .schengen:
            return codes.contains(where: SchengenArea.members.contains)
        case .outside(let code):
            return !codes.isEmpty && !codes.contains(code)
        }
    }
}

/// The period a limit is measured over.
public enum DayLimitWindow: Codable, Sendable, Equatable, Hashable {
    /// The last N days, ending on the day being evaluated.
    case rolling(days: Int)
    case calendarYear
    /// A year that starts on a fixed month and day (UK tax year: 6 April).
    case yearStarting(month: Int, day: Int)

    /// The window containing `day`.
    public func range(containing day: Int) -> ClosedRange<Int> {
        switch self {
        case .rolling(let days):
            return (day - max(1, days) + 1)...day
        case .calendarYear:
            let year = EpochDay(value: day).civil().year
            let start = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
            let end = EpochDay.daysFromCivil(year: year + 1, month: 1, day: 1) - 1
            return start...end
        case .yearStarting(let month, let startDay):
            let year = EpochDay(value: day).civil().year
            let thisYear = EpochDay.daysFromCivil(year: year, month: month, day: startDay)
            let startYear = day >= thisYear ? year : year - 1
            let start = EpochDay.daysFromCivil(year: startYear, month: month, day: startDay)
            let end = EpochDay.daysFromCivil(year: startYear + 1, month: month, day: startDay) - 1
            return start...end
        }
    }

    /// True when the window slides with the calendar instead of resetting.
    public var isRolling: Bool {
        if case .rolling = self { return true }
        return false
    }

    /// How much history an evaluation on any day needs.
    public var lookbackDays: Int {
        switch self {
        case .rolling(let days): return max(1, days)
        case .calendarYear, .yearStarting: return 366
        }
    }
}

/// Whether the number is a ceiling to stay under or a floor to reach.
public enum DayLimitGoal: String, Codable, Sendable, CaseIterable {
    case stayUnder
    case reachAtLeast
}

/// One user-defined day count: "no more than 90 Schengen days in any 180".
public struct DayLimitRule: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var scope: DayLimitScope
    public var window: DayLimitWindow
    public var limit: Int
    public var goal: DayLimitGoal

    public init(
        id: String = UUID().uuidString,
        name: String,
        scope: DayLimitScope,
        window: DayLimitWindow,
        limit: Int,
        goal: DayLimitGoal = .stayUnder
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.window = window
        self.limit = limit
        self.goal = goal
    }

    // MARK: Presets

    /// 90 days in any rolling 180, across the whole Schengen area.
    public static func schengen() -> DayLimitRule {
        DayLimitRule(
            name: "Schengen 90/180",
            scope: .schengen,
            window: .rolling(days: 180),
            limit: 90
        )
    }

    /// The common 183-day tax-residency test, per calendar year.
    public static func calendarYear183(country: String, countryName: String) -> DayLimitRule {
        DayLimitRule(
            name: "183 days in \(countryName)",
            scope: .country(country),
            window: .calendarYear,
            limit: 183
        )
    }

    /// Days in the UK across its 6 April tax year.
    public static func ukTaxYear() -> DayLimitRule {
        DayLimitRule(
            name: "UK tax year",
            scope: .country("GB"),
            window: .yearStarting(month: 4, day: 6),
            limit: 183
        )
    }

    /// Absences from the UK: 180 whole days in any rolling 12 months, the
    /// continuous-residence test for settlement.
    public static func ukAbsences() -> DayLimitRule {
        DayLimitRule(
            name: "UK absences",
            scope: .outside("GB"),
            window: .rolling(days: 365),
            limit: 180
        )
    }

    /// Short window description for rows and widgets.
    public var windowLabel: String {
        switch window {
        case .rolling(let days): return "any \(days) days"
        case .calendarYear: return "calendar year"
        case .yearStarting(let month, let day):
            let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            let name = (1...12).contains(month) ? names[month - 1] : "?"
            return "year from \(day) \(name)"
        }
    }
}

/// Where a rule stands on a given day.
public struct DayLimitStatus: Sendable, Equatable, Identifiable {
    public enum Level: String, Sendable, Codable {
        /// Comfortably inside a ceiling.
        case clear
        /// Past 60% of a ceiling.
        case watch
        /// Past 85% of a ceiling, or exactly on it.
        case close
        /// Over a ceiling.
        case over
        /// Working toward a floor.
        case building
        /// Floor reached.
        case reached
    }

    public var id: String { rule.id }

    public let rule: DayLimitRule
    public let asOf: Int
    /// The window containing `asOf`.
    public let window: ClosedRange<Int>
    /// Counted days in the window up to and including `asOf`.
    public let used: Int
    /// Days in the window up to `asOf` with no verdict at all. They can't be
    /// counted either way, so the real figure may be higher.
    public let unknownDays: Int
    /// `asOf` itself counts toward the rule.
    public let countsToday: Bool
    public let level: Level
    /// Ceilings only: more consecutive counted days, starting tomorrow,
    /// before the count would exceed the limit. For a fixed window this can
    /// run past the reset (the stay simply continues into the next window),
    /// so compare with `daysUntilReset` before calling it a deadline. Nil
    /// when no stay can exceed the limit (a limit as long as its window).
    public let runwayDays: Int?

    /// Fixed windows: the limit can't be exceeded before the window resets.
    public var isSafeUntilReset: Bool {
        guard let reset = daysUntilReset, rule.goal == .stayUnder else { return false }
        return used <= rule.limit && remaining >= reset
    }
    /// Rolling ceilings at or over the limit: the first future day on which
    /// one more counted day would be allowed again, assuming none before it.
    public let reliefDay: Int?
    /// Fixed windows: days after `asOf` until the window resets.
    public let daysUntilReset: Int?

    public var remaining: Int { max(0, rule.limit - used) }
    public var overBy: Int { max(0, used - rule.limit) }

    /// 0…1 for gauges; clamps over-limit to full.
    public var fraction: Double {
        guard rule.limit > 0 else { return 1 }
        return min(1, max(0, Double(used) / Double(rule.limit)))
    }

    /// The number a glance needs: "56 days left", "4 days over", "12 to go".
    public var headline: String {
        func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }
        switch rule.goal {
        case .stayUnder:
            if used > rule.limit { return "\(days(overBy)) over" }
            if used == rule.limit { return "At the limit" }
            return "\(days(remaining)) left"
        case .reachAtLeast:
            if used >= rule.limit { return "Reached" }
            return "\(days(remaining)) to go"
        }
    }

    /// "34 of 90 days · any 180 days"
    public var detail: String {
        "\(used) of \(rule.limit) days · \(rule.windowLabel)"
    }
}

/// Pure day-limit maths over resolved days. The app passes the ledger's
/// verdicts in; nothing here reads a clock or a database.
public enum DayLimitEvaluator {
    /// Simulation horizon for runway and trip planning.
    private static let horizon = 800

    public static func evaluate(
        rule: DayLimitRule, days: [ResolvedDay], asOf: Int
    ) -> DayLimitStatus {
        let history = History(rule: rule, days: days, asOf: asOf)
        let window = rule.window.range(containing: asOf)
        let countedTo = min(asOf, window.upperBound)
        let used = history.counted(window.lowerBound...countedTo)
        let unknown = history.unknown(window.lowerBound...countedTo)

        let level: DayLimitStatus.Level
        switch rule.goal {
        case .stayUnder:
            if used > rule.limit {
                level = .over
            } else if used * 100 >= rule.limit * 85 {
                level = .close
            } else if used * 100 >= rule.limit * 60 {
                level = .watch
            } else {
                level = .clear
            }
        case .reachAtLeast:
            level = used >= rule.limit ? .reached : .building
        }

        var runway: Int?
        var relief: Int?
        if rule.goal == .stayUnder {
            runway = maxStay(rule: rule, history: history, entryDay: asOf + 1)
            if rule.window.isRolling, used >= rule.limit {
                relief = firstAllowedDay(rule: rule, history: history, after: asOf)
            }
        }

        return DayLimitStatus(
            rule: rule,
            asOf: asOf,
            window: window,
            used: used,
            unknownDays: unknown,
            countsToday: history.isCounted(asOf),
            level: level,
            runwayDays: runway,
            reliefDay: relief,
            daysUntilReset: rule.window.isRolling ? nil : window.upperBound - asOf
        )
    }

    /// Trip planning: arriving on `entryDay` and counting every day from
    /// then, how many days fit before the limit is exceeded? Assumes no
    /// counted days between `asOf` and the arrival. Nil = no ceiling in reach.
    public static func maxStay(
        rule: DayLimitRule, days: [ResolvedDay], asOf: Int, entryDay: Int
    ) -> Int? {
        let history = History(rule: rule, days: days, asOf: asOf)
        return maxStay(rule: rule, history: history, entryDay: max(entryDay, asOf + 1))
    }

    private static func maxStay(rule: DayLimitRule, history: History, entryDay: Int) -> Int? {
        guard rule.limit >= 0 else { return 0 }
        for offset in 0..<horizon {
            let day = entryDay + offset
            let window = rule.window.range(containing: day)
            // History inside the window plus the planned stay so far.
            let plannedStart = max(entryDay, window.lowerBound)
            let planned = day - plannedStart + 1
            let total = history.counted(window.lowerBound...min(day, window.upperBound)) + planned
            if total > rule.limit {
                return offset
            }
        }
        return nil
    }

    /// First day after `after` on which one more counted day keeps the
    /// rolling count within the limit, assuming nothing counted in between.
    private static func firstAllowedDay(rule: DayLimitRule, history: History, after: Int) -> Int? {
        for offset in 1...horizon {
            let day = after + offset
            let window = rule.window.range(containing: day)
            if history.counted(window) + 1 <= rule.limit {
                return day
            }
        }
        return nil
    }

    /// Counted/unknown flags with prefix sums, so every window query is O(1).
    private struct History {
        private let base: Int
        private let asOf: Int
        private let countedPrefix: [Int]
        private let unknownPrefix: [Int]
        private let countedFlags: [Bool]

        init(rule: DayLimitRule, days: [ResolvedDay], asOf: Int) {
            self.asOf = asOf
            let lowest = min(days.map(\.day).min() ?? asOf, asOf)
            base = lowest
            let length = asOf - lowest + 1
            var counted = [Bool](repeating: false, count: length)
            var known = [Bool](repeating: false, count: length)
            for day in days where day.day >= lowest && day.day <= asOf {
                let index = day.day - lowest
                if !day.countryCodes.isEmpty { known[index] = true }
                if rule.scope.counts(day.countryCodes) { counted[index] = true }
            }
            var cPrefix = [Int](repeating: 0, count: length + 1)
            var uPrefix = [Int](repeating: 0, count: length + 1)
            for index in 0..<length {
                cPrefix[index + 1] = cPrefix[index] + (counted[index] ? 1 : 0)
                uPrefix[index + 1] = uPrefix[index] + (known[index] ? 0 : 1)
            }
            countedPrefix = cPrefix
            unknownPrefix = uPrefix
            countedFlags = counted
        }

        func isCounted(_ day: Int) -> Bool {
            guard day >= base, day <= asOf else { return false }
            return countedFlags[day - base]
        }

        /// Counted days in `range`, limited to recorded history (≤ asOf).
        func counted(_ range: ClosedRange<Int>) -> Int {
            sum(countedPrefix, range)
        }

        /// Days in `range` without a verdict. Days before the first provided
        /// day are outside what the caller asked about and don't count.
        func unknown(_ range: ClosedRange<Int>) -> Int {
            sum(unknownPrefix, range)
        }

        private func sum(_ prefix: [Int], _ range: ClosedRange<Int>) -> Int {
            let lower = max(range.lowerBound, base)
            let upper = min(range.upperBound, asOf)
            guard lower <= upper else { return 0 }
            return prefix[upper - base + 1] - prefix[lower - base]
        }
    }
}
