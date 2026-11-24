import Foundation

/// Lifetime numbers for the Passport and Home insight cards. Everything is a
/// pure function of resolved days, so a manual edit or a gap-fill change
/// moves these the same instant it moves the calendar.
public struct TravelInsights: Sendable, Equatable {
    public struct FarthestPoint: Sendable, Equatable {
        public let code: String
        public let km: Int
    }

    public struct YearTotals: Sendable, Equatable, Identifiable {
        public var id: Int { year }
        public let year: Int
        /// Distinct countries seen that year.
        public let countries: Int
        /// Countries never seen in an earlier year.
        public let newCountries: Int
        public let travelDays: Int
    }

    /// This year against the same stretch of last year.
    public struct Pace: Sendable, Equatable {
        public let dayOfYear: Int
        public let countriesThisYear: Int
        public let countriesLastYear: Int
        public let travelDaysThisYear: Int
        public let travelDaysLastYear: Int
    }

    public let trackedDays: Int
    public let travelDays: Int
    public let countries: Int
    /// Great-circle kilometres along the chain of countries, in order.
    /// Approximate by construction: it measures between one representative
    /// point per country, not door to door.
    public let totalKm: Int
    /// Legs that could be measured (both ends had a coordinate).
    public let legs: Int
    public let farthest: FarthestPoint?
    public let longestAway: YearInReviewStats.AwayStretch?
    /// 1…12: the month with the most travel days across every year.
    public let favouriteMonth: Int?
    /// Mean length of an away-from-home trip, in days.
    public let averageTripDays: Double?
    public let longestHomeStretch: Int
    public let byYear: [YearTotals]
    public let pace: Pace?
    /// Most distinct countries inside any 7-day window.
    public let mostCountriesInAWeek: Int
    /// Most distinct countries in a single calendar year.
    public let bestYearCountries: Int
    public let crossedEquator: Bool

    /// Share of tracked days spent away from home, 0…1.
    public var awayShare: Double {
        trackedDays > 0 ? Double(travelDays) / Double(trackedDays) : 0
    }
}

public enum TravelInsightsEngine {
    /// - Parameters:
    ///   - days: every resolved day from the first fact to `today`, ascending.
    ///   - coordinate: one representative point per country. The app prefers
    ///     the user's own busiest city there and falls back to the outline's
    ///     centre; nil just drops that leg from the distance.
    public static func compute(
        days: [ResolvedDay],
        homeTimeline: HomeTimeline,
        today: Int,
        coordinate: (String) -> GeoPoint?
    ) -> TravelInsights {
        func home(_ day: Int) -> String? { homeTimeline.home(on: day) }
        func isAway(_ day: ResolvedDay) -> Bool {
            !day.countryCodes.isEmpty && day.countryCodes != [home(day.day)].compactMap { $0 }
        }

        var tracked = 0
        var travel = 0
        var seen: Set<String> = []
        var monthTravel: [Int: Int] = [:]
        var yearCountries: [Int: Set<String>] = [:]
        var yearNew: [Int: Int] = [:]
        var yearTravel: [Int: Int] = [:]

        // The chain of countries in the order they were entered.
        var path: [String] = []

        // Away stretches (may span several countries) and home stretches.
        var longestAway: YearInReviewStats.AwayStretch?
        var awayStart: Int?
        var awayCodes: [String] = []
        var awayLengths: [Int] = []
        var homeRun = 0
        var longestHome = 0
        var previousDay: Int?

        func closeAway(endDay: Int) {
            guard let start = awayStart else { return }
            let stretch = YearInReviewStats.AwayStretch(
                startDay: start, endDay: endDay, countryCodes: awayCodes
            )
            awayLengths.append(stretch.dayCount)
            if stretch.dayCount > (longestAway?.dayCount ?? 0) { longestAway = stretch }
            awayStart = nil
            awayCodes = []
        }

        // Sliding 7-day window of country sets for the border-hopper stat.
        var recent: [(day: Int, codes: [String])] = []
        var mostInWeek = 0

        for day in days {
            guard !day.countryCodes.isEmpty else {
                // An unknown day ends both kinds of run: nothing is known
                // about where it was spent.
                if let previous = previousDay { closeAway(endDay: previous) }
                homeRun = 0
                previousDay = nil
                continue
            }
            tracked += 1
            let (year, month, _) = EpochDay(value: day.day).civil()

            for code in day.countryCodes {
                yearCountries[year, default: []].insert(code)
                if seen.insert(code).inserted {
                    yearNew[year, default: 0] += 1
                }
            }

            // Extend the path. A country already at the tail is still where
            // we are, so only the arrivals are appended: on a border day that
            // is the other half, whichever order the evidence listed them in.
            var arrivals = day.countryCodes
            if let tail = path.last, let index = arrivals.firstIndex(of: tail) {
                arrivals.remove(at: index)
            }
            for code in arrivals where path.last != code {
                path.append(code)
            }

            if isAway(day) {
                travel += 1
                monthTravel[month, default: 0] += 1
                yearTravel[year, default: 0] += 1
                if awayStart == nil { awayStart = day.day }
                for code in day.countryCodes where !awayCodes.contains(code) && code != home(day.day) {
                    awayCodes.append(code)
                }
                homeRun = 0
            } else {
                if let previous = previousDay { closeAway(endDay: previous) }
                homeRun += 1
                longestHome = max(longestHome, homeRun)
            }

            recent.append((day.day, day.countryCodes))
            recent.removeAll { $0.day <= day.day - 7 }
            mostInWeek = max(mostInWeek, Set(recent.flatMap(\.codes)).count)

            previousDay = day.day
        }
        if let previous = previousDay { closeAway(endDay: previous) }

        // Distance along the path.
        var metres = 0.0
        var legs = 0
        var index = 1
        while index < path.count {
            if let a = coordinate(path[index - 1]), let b = coordinate(path[index]) {
                metres += Haversine.meters(from: a, to: b)
                legs += 1
            }
            index += 1
        }

        // Farthest from today's home.
        var farthest: TravelInsights.FarthestPoint?
        if let homeCode = homeTimeline.current, let origin = coordinate(homeCode) {
            for code in seen.sorted() where code != homeCode {
                guard let point = coordinate(code) else { continue }
                let km = Int((Haversine.meters(from: origin, to: point) / 1000).rounded())
                if km > (farthest?.km ?? -1) {
                    farthest = TravelInsights.FarthestPoint(code: code, km: km)
                }
            }
        }

        let latitudes = seen.compactMap { coordinate($0)?.latitude }
        let crossedEquator = latitudes.contains { $0 < 0 } && latitudes.contains { $0 > 0 }

        let favouriteMonth = monthTravel
            .sorted { ($0.value, -$0.key) > ($1.value, -$1.key) }
            .first?.key

        let years = Set(yearCountries.keys).union(yearTravel.keys).sorted()
        let byYear = years.map {
            TravelInsights.YearTotals(
                year: $0,
                countries: yearCountries[$0]?.count ?? 0,
                newCountries: yearNew[$0] ?? 0,
                travelDays: yearTravel[$0] ?? 0
            )
        }

        return TravelInsights(
            trackedDays: tracked,
            travelDays: travel,
            countries: seen.count,
            totalKm: Int((metres / 1000).rounded()),
            legs: legs,
            farthest: farthest,
            longestAway: longestAway,
            favouriteMonth: favouriteMonth,
            averageTripDays: awayLengths.isEmpty
                ? nil
                : Double(awayLengths.reduce(0, +)) / Double(awayLengths.count),
            longestHomeStretch: longestHome,
            byYear: byYear,
            pace: pace(days: days, homeTimeline: homeTimeline, today: today),
            mostCountriesInAWeek: mostInWeek,
            bestYearCountries: yearCountries.values.map(\.count).max() ?? 0,
            crossedEquator: crossedEquator
        )
    }

    /// Jan 1 → today this year, against Jan 1 → the same day-of-year last
    /// year. Nil until there is any data from last year to compare with.
    static func pace(
        days: [ResolvedDay], homeTimeline: HomeTimeline, today: Int
    ) -> TravelInsights.Pace? {
        let year = EpochDay(value: today).civil().year
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let lastJan1 = EpochDay.daysFromCivil(year: year - 1, month: 1, day: 1)
        let dayOfYear = today - jan1 + 1
        let lastEnd = min(lastJan1 + dayOfYear - 1, jan1 - 1)

        var thisCountries: Set<String> = []
        var lastCountries: Set<String> = []
        var thisTravel = 0
        var lastTravel = 0
        var sawLastYear = false

        for day in days where !day.countryCodes.isEmpty {
            let away = day.countryCodes != [homeTimeline.home(on: day.day)].compactMap { $0 }
            if day.day >= jan1, day.day <= today {
                thisCountries.formUnion(day.countryCodes)
                if away { thisTravel += 1 }
            } else if day.day >= lastJan1, day.day <= lastEnd {
                sawLastYear = true
                lastCountries.formUnion(day.countryCodes)
                if away { lastTravel += 1 }
            }
        }
        guard sawLastYear else { return nil }
        return TravelInsights.Pace(
            dayOfYear: dayOfYear,
            countriesThisYear: thisCountries.count,
            countriesLastYear: lastCountries.count,
            travelDaysThisYear: thisTravel,
            travelDaysLastYear: lastTravel
        )
    }
}

/// The four corners of someone's map, from the cities they have evidence in.
public struct CityExtremes: Sendable, Equatable {
    public let northernmost: CityDays?
    public let southernmost: CityDays?
    public let easternmost: CityDays?
    public let westernmost: CityDays?

    public static func compute(_ cities: [CityDays]) -> CityExtremes {
        CityExtremes(
            northernmost: cities.max { ($0.latitude, $0.key) < ($1.latitude, $1.key) },
            southernmost: cities.min { ($0.latitude, $0.key) < ($1.latitude, $1.key) },
            easternmost: cities.max { ($0.longitude, $0.key) < ($1.longitude, $1.key) },
            westernmost: cities.min { ($0.longitude, $0.key) < ($1.longitude, $1.key) }
        )
    }
}
