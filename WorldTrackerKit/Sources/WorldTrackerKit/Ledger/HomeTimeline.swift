import Foundation

/// One stretch of "this is where I lived". `startDay` nil means the period
/// reaches back to the beginning of time (the first home).
public struct HomePeriod: Sendable, Equatable, Codable {
    public let startDay: Int?
    public let countryCode: String

    public init(startDay: Int?, countryCode: String) {
        self.startDay = startDay
        self.countryCode = countryCode
    }
}

/// Where home was on any given day. People move — a single global home
/// country would call someone's old life abroad "travel", which is exactly
/// the bug this type exists to fix.
public struct HomeTimeline: Sendable, Equatable, Codable {
    /// Sorted by start ascending; the open-start period (if any) first.
    /// Each period runs until the next one begins; the last runs forever.
    public let periods: [HomePeriod]

    public init(periods: [HomePeriod]) {
        // Normalize: open-start first, then by start day; duplicate starts
        // collapse (last writer wins); adjacent same-country periods merge —
        // a malformed list can't corrupt lookups.
        var byStart: [Int?: String] = [:]
        for period in periods {
            byStart[period.startDay] = period.countryCode
        }
        let sorted = byStart
            .map { HomePeriod(startDay: $0.key, countryCode: $0.value) }
            .sorted { ($0.startDay ?? Int.min) < ($1.startDay ?? Int.min) }
        var merged: [HomePeriod] = []
        for period in sorted {
            if period.countryCode != merged.last?.countryCode {
                merged.append(period)
            }
        }
        self.periods = merged
    }

    public static let empty = HomeTimeline(periods: [])

    /// Back-compat bridge for the single-home world.
    public static func single(_ countryCode: String?) -> HomeTimeline {
        guard let countryCode else { return .empty }
        return HomeTimeline(periods: [HomePeriod(startDay: nil, countryCode: countryCode)])
    }

    /// Home on a specific day, or nil before the first period / when empty.
    public func home(on day: Int) -> String? {
        var result: String?
        for period in periods {
            if let start = period.startDay, start > day { break }
            result = period.countryCode
        }
        return result
    }

    /// Today's home — the last period.
    public var current: String? {
        periods.last?.countryCode
    }

    public var isEmpty: Bool { periods.isEmpty }

    /// The home covering the most calendar days of `range` — the "display
    /// home" for a year in Wrapped. Ties break toward the later period.
    public func dominantHome(in range: ClosedRange<Int>) -> String? {
        guard !periods.isEmpty else { return nil }
        var coverage: [String: Int] = [:]
        var order: [String] = []
        for (index, period) in periods.enumerated() {
            let start = max(period.startDay ?? Int.min, range.lowerBound)
            let end: Int
            if index + 1 < periods.count, let nextStart = periods[index + 1].startDay {
                end = min(nextStart - 1, range.upperBound)
            } else {
                end = range.upperBound
            }
            guard start <= end else { continue }
            coverage[period.countryCode, default: 0] += end - start + 1
            if !order.contains(period.countryCode) { order.append(period.countryCode) }
        }
        // Later period wins ties, so compare with stable later-preference.
        return order.reversed().max { (coverage[$0] ?? 0) < (coverage[$1] ?? 0) }
    }

    /// Stable identity for cache keys.
    public var cacheKey: String {
        guard !periods.isEmpty else { return "-" }
        return periods
            .map { "\($0.countryCode)|\($0.startDay.map(String.init) ?? "")" }
            .joined(separator: ":")
    }
}
