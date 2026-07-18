import Foundation

/// A place with its visit days — the app maps PlaceSnapshot+VisitSnapshot
/// into this so the computer stays Foundation-only.
public struct PlaceVisitInput: Sendable, Equatable {
    public let name: String
    public let city: String?
    public let countryCode: String?
    public let visitEpochDays: [Int]

    public init(name: String, city: String?, countryCode: String?, visitEpochDays: [Int]) {
        self.name = name
        self.city = city
        self.countryCode = countryCode
        self.visitEpochDays = visitEpochDays
    }
}

/// Everything a "Year in Travel" story needs, precomputed and pure.
public struct YearInReviewStats: Sendable, Equatable, Codable {
    public struct RankedCountry: Sendable, Equatable, Codable {
        public let code: String
        public let days: Int

        public init(code: String, days: Int) {
            self.code = code
            self.days = days
        }
    }

    public struct MonthActivity: Sendable, Equatable, Codable {
        public let month: Int
        public let travelDays: Int

        public init(month: Int, travelDays: Int) {
            self.month = month
            self.travelDays = travelDays
        }
    }

    /// "Longest trip" = the longest contiguous away-from-home stretch; it may
    /// span several countries, which shares better than a single-country run.
    public struct AwayStretch: Sendable, Equatable, Codable {
        public let startDay: Int
        public let endDay: Int
        /// Chronological, deduped.
        public let countryCodes: [String]

        public var dayCount: Int { endDay - startDay + 1 }

        public init(startDay: Int, endDay: Int, countryCodes: [String]) {
            self.startDay = startDay
            self.endDay = endDay
            self.countryCodes = countryCodes
        }
    }

    public struct PlaceHighlight: Sendable, Equatable, Codable {
        public let name: String
        public let city: String?
        public let countryCode: String?
        public let visitCount: Int

        public init(name: String, city: String?, countryCode: String?, visitCount: Int) {
            self.name = name
            self.city = city
            self.countryCode = countryCode
            self.visitCount = visitCount
        }
    }

    public let year: Int
    /// Days with any verdict — powers the minimum-data gate.
    public let trackedDays: Int
    public let countriesVisited: Int
    public let travelDays: Int
    public let borderCrossings: Int
    /// ≤ 5, by days descending.
    public let topCountries: [RankedCountry]
    public let longestTrip: AwayStretch?
    /// Countries never seen before this year, in order of first appearance.
    public let firstVisits: [String]
    public let busiestMonth: MonthActivity?
    /// Every visited code ordered by first appearance — drives map light-up.
    public let firstAppearanceOrder: [String]
    public let mostVisitedPlace: PlaceHighlight?
    public let homeCountry: String?

    /// Enough data for a Wrapped worth showing.
    public var meetsMinimumData: Bool {
        trackedDays >= 10 && (countriesVisited >= 2 || travelDays >= 5)
    }
}

public enum YearInReview {
    public static func compute(
        year: Int,
        days: [ResolvedDay],
        homeCountry: String?,
        priorCountryCodes: Set<String>,
        places: [PlaceVisitInput] = []
    ) -> YearInReviewStats {
        let stats = DayLedgerResolver.stats(for: days, home: homeCountry)
        let trackedDays = days.filter { !$0.countryCodes.isEmpty }.count

        let ranked = stats.daysPerCountry
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(5)
            .map { YearInReviewStats.RankedCountry(code: $0.key, days: $0.value) }

        // First appearances.
        var firstAppearance: [String] = []
        var seen: Set<String> = []
        for day in days {
            for code in day.countryCodes where !seen.contains(code) {
                seen.insert(code)
                firstAppearance.append(code)
            }
        }
        let firstVisits = firstAppearance.filter { !priorCountryCodes.contains($0) }

        // Longest away stretch.
        var longest: YearInReviewStats.AwayStretch?
        var runStart: Int?
        var runCodes: [String] = []
        var runSeen: Set<String> = []

        func closeRun(endDay: Int) {
            guard let start = runStart else { return }
            let stretch = YearInReviewStats.AwayStretch(
                startDay: start, endDay: endDay, countryCodes: runCodes
            )
            if stretch.dayCount > (longest?.dayCount ?? 0) {
                longest = stretch
            }
            runStart = nil
            runCodes = []
            runSeen = []
        }

        var previousDay: Int?
        for day in days {
            let isAway = !day.countryCodes.isEmpty
                && day.countryCodes != [homeCountry].compactMap({ $0 })
            if isAway {
                if runStart == nil {
                    runStart = day.day
                }
                for code in day.countryCodes where !runSeen.contains(code) {
                    runSeen.insert(code)
                    runCodes.append(code)
                }
            } else if let previous = previousDay {
                closeRun(endDay: previous)
            }
            previousDay = day.day
        }
        if let previous = previousDay {
            closeRun(endDay: previous)
        }

        // Busiest month (by travel days; earliest month wins ties).
        var byMonth: [Int: Int] = [:]
        for day in days {
            let isTravel = !day.countryCodes.isEmpty
                && day.countryCodes != [homeCountry].compactMap({ $0 })
            guard isTravel else { continue }
            let month = EpochDay(value: day.day).civil().month
            byMonth[month, default: 0] += 1
        }
        let busiest = byMonth
            .sorted { ($0.value, -$0.key) > ($1.value, -$1.key) }
            .first
            .map { YearInReviewStats.MonthActivity(month: $0.key, travelDays: $0.value) }

        // Most-visited place: prefer somewhere NOT in the home country when a
        // non-home candidate has 2+ visits this year.
        let yearRange: ClosedRange<Int>? = days.isEmpty ? nil : days[0].day...days[days.count - 1].day
        var bestOverall: YearInReviewStats.PlaceHighlight?
        var bestAway: YearInReviewStats.PlaceHighlight?
        if let range = yearRange {
            for place in places {
                let visits = place.visitEpochDays.filter(range.contains).count
                guard visits > 0 else { continue }
                let highlight = YearInReviewStats.PlaceHighlight(
                    name: place.name,
                    city: place.city,
                    countryCode: place.countryCode,
                    visitCount: visits
                )
                if visits > (bestOverall?.visitCount ?? 0) {
                    bestOverall = highlight
                }
                if place.countryCode != homeCountry, visits >= 2,
                   visits > (bestAway?.visitCount ?? 0) {
                    bestAway = highlight
                }
            }
        }

        return YearInReviewStats(
            year: year,
            trackedDays: trackedDays,
            countriesVisited: stats.countriesVisited,
            travelDays: stats.travelDays,
            borderCrossings: stats.borderCrossings,
            topCountries: Array(ranked),
            longestTrip: longest,
            firstVisits: firstVisits,
            busiestMonth: busiest,
            firstAppearanceOrder: firstAppearance,
            mostVisitedPlace: bestAway ?? bestOverall,
            homeCountry: homeCountry
        )
    }
}
