import Foundation

// The power-user layer over `DayLimitEvaluator`: planned trips and their
// forecast, how a rule has stood historically, the stretches behind a count
// (for a report), and where the ledger is thin. All pure.

// MARK: - Planned trips

/// A trip that hasn't happened yet. Plans are settings, not ledger facts:
/// once a planned day arrives, recorded evidence takes over.
public struct PlannedTrip: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var countryCode: String
    public var startDay: Int
    public var endDay: Int

    public init(id: String = UUID().uuidString, countryCode: String, startDay: Int, endDay: Int) {
        self.id = id
        self.countryCode = countryCode
        self.startDay = min(startDay, endDay)
        self.endDay = max(startDay, endDay)
    }

    public var dayCount: Int { endDay - startDay + 1 }
}

public enum TripPlans {
    /// Plans that still have a future day in them, soonest first.
    public static func upcoming(_ plans: [PlannedTrip], today: Int) -> [PlannedTrip] {
        plans.filter { $0.endDay > today }
            .sorted { ($0.startDay, $0.countryCode) < ($1.startDay, $1.countryCode) }
    }

    /// The future as the plans describe it: one resolved day for every day
    /// from tomorrow to the end of the last plan.
    ///
    /// A day inside a plan is in that plan's country. The first and last day
    /// of a trip also touch home (you wake up or go to bed there), unless
    /// another plan covers the neighbouring day, which makes it a direct
    /// hop. Days between plans are spent at home; with no home set they are
    /// unknown.
    public static func projectedDays(
        plans: [PlannedTrip], after today: Int, home: String?
    ) -> [ResolvedDay] {
        let future = upcoming(plans, today: today)
        guard let last = future.map(\.endDay).max(), last > today else { return [] }

        func countries(on day: Int) -> [String] {
            var seen: [String] = []
            for plan in future where plan.startDay <= day && day <= plan.endDay {
                if !seen.contains(plan.countryCode) { seen.append(plan.countryCode) }
            }
            return seen
        }

        return ((today + 1)...last).map { day in
            var codes = countries(on: day)
            if codes.isEmpty {
                codes = home.map { [$0] } ?? []
            } else if let home, !codes.contains(home) {
                let leavesHome = future.contains { $0.startDay == day } && countries(on: day - 1).isEmpty
                let returnsHome = future.contains { $0.endDay == day } && countries(on: day + 1).isEmpty
                if leavesHome || returnsHome {
                    codes.insert(home, at: 0)
                }
            }
            return ResolvedDay(day: day, countryCodes: codes, source: nil, isFilled: false)
        }
    }
}

/// Where a rule ends up if every plan happens.
public struct DayLimitForecast: Sendable, Equatable {
    /// The highest count reached on any day from today to the end of plans.
    public let peakUsed: Int
    /// The first day that peak is reached.
    public let peakDay: Int
    /// Ceilings: the first day the count exceeds the limit. Floors: the
    /// first day the target is met. Nil if neither happens.
    public let crossingDay: Int?
    /// The last planned day.
    public let endDay: Int
    public let usedAtEnd: Int
    public let level: DayLimitStatus.Level
}

// MARK: - History

/// One fixed window (a calendar or tax year) and what was counted in it.
public struct DayLimitWindowTotal: Sendable, Equatable, Identifiable {
    public var id: Int { window.lowerBound }
    public let window: ClosedRange<Int>
    public let used: Int
    public let isCurrent: Bool
}

/// The most a rolling rule has ever stood at.
public struct DayLimitPeak: Sendable, Equatable {
    public let used: Int
    /// The last day of the window that held it (the latest such day).
    public let day: Int
}

/// One unbroken run of counted days: a stay, or for an absence rule, an
/// absence.
public struct CountedStretch: Sendable, Equatable, Identifiable {
    public var id: Int { startDay }
    public let startDay: Int
    public let endDay: Int
    /// Chronological, deduped. For a country rule this is just the country
    /// plus anywhere a border day touched.
    public let countryCodes: [String]

    public var days: Int { endDay - startDay + 1 }
}

extension DayLimitEvaluator {
    /// Counted flags over a contiguous span, with prefix sums.
    private struct Counter {
        let base: Int
        let prefix: [Int]

        init(rule: DayLimitRule, days: [ResolvedDay], through end: Int) {
            let lowest = min(days.map(\.day).min() ?? end, end)
            base = lowest
            var flags = [Bool](repeating: false, count: end - lowest + 1)
            for day in days where day.day >= lowest && day.day <= end {
                if rule.scope.counts(day.countryCodes) { flags[day.day - lowest] = true }
            }
            var sums = [Int](repeating: 0, count: flags.count + 1)
            for index in flags.indices { sums[index + 1] = sums[index] + (flags[index] ? 1 : 0) }
            prefix = sums
        }

        /// Counted days in `range`, up to and including `cap`.
        func count(_ range: ClosedRange<Int>, upTo cap: Int) -> Int {
            let lower = max(range.lowerBound, base)
            let upper = min(range.upperBound, cap, base + prefix.count - 2)
            guard lower <= upper else { return 0 }
            return prefix[upper - base + 1] - prefix[lower - base]
        }
    }

    /// Runs the rule forward over `planned` days (see
    /// `TripPlans.projectedDays`). Nil when nothing is planned.
    public static func forecast(
        rule: DayLimitRule, days: [ResolvedDay], planned: [ResolvedDay], asOf: Int
    ) -> DayLimitForecast? {
        let future = planned.filter { $0.day > asOf }
        guard let end = future.map(\.day).max() else { return nil }
        let counter = Counter(
            rule: rule, days: days.filter { $0.day <= asOf } + future, through: end
        )

        var peak = -1
        var peakDay = asOf
        var crossing: Int?
        var usedAtEnd = 0
        for day in asOf...end {
            let used = counter.count(rule.window.range(containing: day), upTo: day)
            if used > peak {
                peak = used
                peakDay = day
            }
            if crossing == nil {
                let crossed = rule.goal == .stayUnder ? used > rule.limit : used >= rule.limit
                if crossed { crossing = day }
            }
            usedAtEnd = used
        }

        let level: DayLimitStatus.Level
        switch rule.goal {
        case .stayUnder:
            if peak > rule.limit {
                level = .over
            } else if peak * 100 >= rule.limit * 85 {
                level = .close
            } else if peak * 100 >= rule.limit * 60 {
                level = .watch
            } else {
                level = .clear
            }
        case .reachAtLeast:
            level = peak >= rule.limit ? .reached : .building
        }
        return DayLimitForecast(
            peakUsed: peak, peakDay: peakDay, crossingDay: crossing,
            endDay: end, usedAtEnd: usedAtEnd, level: level
        )
    }

    /// Rolling rules: the highest the count has ever been, over every day of
    /// recorded history. Nil for fixed windows or an empty ledger.
    public static func peak(rule: DayLimitRule, days: [ResolvedDay], asOf: Int) -> DayLimitPeak? {
        guard rule.window.isRolling, let first = days.map(\.day).min(), first <= asOf else {
            return nil
        }
        let counter = Counter(rule: rule, days: days, through: asOf)
        var best = DayLimitPeak(used: 0, day: asOf)
        for day in first...asOf {
            let used = counter.count(rule.window.range(containing: day), upTo: day)
            if used >= best.used && used > 0 { best = DayLimitPeak(used: used, day: day) }
        }
        return best.used > 0 ? best : nil
    }

    /// Fixed windows: the current window and the ones before it that hold
    /// any recorded day, newest first.
    public static func pastWindows(
        rule: DayLimitRule, days: [ResolvedDay], asOf: Int, limit: Int = 8
    ) -> [DayLimitWindowTotal] {
        guard !rule.window.isRolling, let first = days.map(\.day).min() else { return [] }
        let counter = Counter(rule: rule, days: days, through: asOf)
        var result: [DayLimitWindowTotal] = []
        var window = rule.window.range(containing: asOf)
        while result.count < limit, window.upperBound >= first {
            result.append(DayLimitWindowTotal(
                window: window,
                used: counter.count(window, upTo: asOf),
                isCurrent: window.contains(asOf)
            ))
            window = rule.window.range(containing: window.lowerBound - 1)
        }
        return result
    }

    /// Every unbroken run of counted days inside `range`, newest first: the
    /// line items behind a count.
    public static func stretches(
        rule: DayLimitRule, days: [ResolvedDay], in range: ClosedRange<Int>
    ) -> [CountedStretch] {
        var result: [CountedStretch] = []
        var start: Int?
        var last = 0
        var codes: [String] = []

        func close() {
            guard let begin = start else { return }
            result.append(CountedStretch(startDay: begin, endDay: last, countryCodes: codes))
            start = nil
            codes = []
        }

        for day in days.sorted(by: { $0.day < $1.day }) where range.contains(day.day) {
            if rule.scope.counts(day.countryCodes) {
                if let _ = start, day.day != last + 1 { close() }
                if start == nil { start = day.day }
                last = day.day
                for code in day.countryCodes where !codes.contains(code) { codes.append(code) }
            } else {
                close()
            }
        }
        close()
        return result.reversed()
    }
}

/// A rule's stretches as a CSV a human (or a caseworker) can read.
public enum DayLimitReport {
    public static func csv(rule: DayLimitRule, stretches: [CountedStretch]) -> String {
        func date(_ day: Int) -> String {
            let c = EpochDay(value: day).civil()
            return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
        }
        var lines = ["rule,first_day,last_day,days,countries"]
        let name = rule.name.replacingOccurrences(of: "\"", with: "'")
        for stretch in stretches.sorted(by: { $0.startDay < $1.startDay }) {
            lines.append(
                "\"\(name)\",\(date(stretch.startDay)),\(date(stretch.endDay)),\(stretch.days),"
                    + stretch.countryCodes.joined(separator: "|")
            )
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - Audit

/// A run of days the ledger has no direct evidence for.
public struct DayRun: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable {
        /// No verdict at all.
        case unknown
        /// Filled in by the gap-fill policy.
        case inferred
    }

    public var id: Int { startDay }
    public let startDay: Int
    public let endDay: Int
    public let kind: Kind
    /// What gap-fill assumed, for inferred runs.
    public let assumedCode: String?

    public var days: Int { endDay - startDay + 1 }
}

public enum DayAudit {
    public struct Coverage: Sendable, Equatable {
        public let evidenced: Int
        public let inferred: Int
        public let unknown: Int

        public var total: Int { evidenced + inferred + unknown }
        /// Share of days backed by direct evidence, 0…1.
        public var evidencedShare: Double {
            total > 0 ? Double(evidenced) / Double(total) : 0
        }
    }

    public static func coverage(_ days: [ResolvedDay]) -> Coverage {
        var evidenced = 0, inferred = 0, unknown = 0
        for day in days {
            if day.countryCodes.isEmpty {
                unknown += 1
            } else if day.isFilled {
                inferred += 1
            } else {
                evidenced += 1
            }
        }
        return Coverage(evidenced: evidenced, inferred: inferred, unknown: unknown)
    }

    /// Unknown and inferred runs, newest first. Unknown runs come before
    /// inferred ones of the same date order only by date; callers filter by
    /// kind if they want one list.
    public static func runs(_ days: [ResolvedDay]) -> [DayRun] {
        var result: [DayRun] = []
        var start: Int?
        var last = 0
        var kind: DayRun.Kind = .unknown
        var code: String?

        func close() {
            guard let begin = start else { return }
            result.append(DayRun(startDay: begin, endDay: last, kind: kind, assumedCode: code))
            start = nil
        }

        for day in days.sorted(by: { $0.day < $1.day }) {
            let dayKind: DayRun.Kind?
            if day.countryCodes.isEmpty {
                dayKind = .unknown
            } else if day.isFilled {
                dayKind = .inferred
            } else {
                dayKind = nil
            }
            guard let dayKind else {
                close()
                continue
            }
            let dayCode = dayKind == .inferred ? day.countryCodes.first : nil
            if start != nil, (dayKind != kind || dayCode != code || day.day != last + 1) { close() }
            if start == nil {
                start = day.day
                kind = dayKind
                code = dayCode
            }
            last = day.day
        }
        close()
        return result.reversed()
    }
}
