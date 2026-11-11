import Foundation

/// A badge with a number to chase. Unlike milestones (which celebrate a
/// crossing once), badges are a standing shelf: locked ones show how far
/// there is to go.
public struct Achievement: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    /// What earns it, phrased as the rule.
    public let detail: String
    /// SF Symbol name; the Kit never imports SwiftUI.
    public let symbol: String
    public let current: Int
    public let target: Int

    public var isUnlocked: Bool { current >= target }

    public var fraction: Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(current) / Double(target)))
    }
}

public enum AchievementEngine {
    /// The numbers every badge is judged on.
    public struct Input: Sendable, Equatable {
        public var countries: Int
        public var continents: Int
        public var travelDays: Int
        public var longestTripDays: Int
        public var totalKm: Int
        public var schengenCountries: Int
        public var crossedEquator: Bool
        public var mostCountriesInAWeek: Int
        public var bestYearCountries: Int
        public var wishlistVisited: Int

        public init(
            countries: Int = 0,
            continents: Int = 0,
            travelDays: Int = 0,
            longestTripDays: Int = 0,
            totalKm: Int = 0,
            schengenCountries: Int = 0,
            crossedEquator: Bool = false,
            mostCountriesInAWeek: Int = 0,
            bestYearCountries: Int = 0,
            wishlistVisited: Int = 0
        ) {
            self.countries = countries
            self.continents = continents
            self.travelDays = travelDays
            self.longestTripDays = longestTripDays
            self.totalKm = totalKm
            self.schengenCountries = schengenCountries
            self.crossedEquator = crossedEquator
            self.mostCountriesInAWeek = mostCountriesInAWeek
            self.bestYearCountries = bestYearCountries
            self.wishlistVisited = wishlistVisited
        }
    }

    /// Earth's equatorial circumference, the "around the world" yardstick.
    public static let earthCircumferenceKm = 40_075

    /// Builds the input from what the insights engine already computed.
    public static func input(
        insights: TravelInsights, stamps: [PassportStamp], wishlistVisited: Int
    ) -> Input {
        Input(
            countries: stamps.count,
            continents: Set(stamps.compactMap(\.continent)).count,
            travelDays: insights.travelDays,
            longestTripDays: insights.longestAway?.dayCount ?? 0,
            totalKm: insights.totalKm,
            schengenCountries: stamps.filter { SchengenArea.members.contains($0.code) }.count,
            crossedEquator: insights.crossedEquator,
            mostCountriesInAWeek: insights.mostCountriesInAWeek,
            bestYearCountries: insights.bestYearCountries,
            wishlistVisited: wishlistVisited
        )
    }

    /// Fixed shelf order: collection, reach, endurance, then the oddities.
    public static func evaluate(_ input: Input) -> [Achievement] {
        func badge(
            _ id: String, _ title: String, _ detail: String, _ symbol: String,
            _ current: Int, _ target: Int
        ) -> Achievement {
            Achievement(
                id: id, title: title, detail: detail, symbol: symbol,
                current: min(current, target), target: target
            )
        }

        return [
            badge("countries-1", "First Stamp", "Log your first country", "seal", input.countries, 1),
            badge("countries-5", "High Five", "5 countries", "hand.raised", input.countries, 5),
            badge("countries-10", "Double Digits", "10 countries", "10.circle", input.countries, 10),
            badge("countries-25", "Quarter Century", "25 countries", "rosette", input.countries, 25),
            badge("countries-50", "Half Century", "50 countries", "crown", input.countries, 50),
            badge("continents-3", "Tri-Continental", "3 continents", "globe.europe.africa", input.continents, 3),
            badge("continents-5", "Five Rings", "5 continents", "circle.hexagongrid", input.continents, 5),
            badge("continents-7", "All Seven", "Every continent", "snowflake", input.continents, 7),
            badge("km-world", "Around the World", "40,075 km between countries", "airplane.circle", input.totalKm, earthCircumferenceKm),
            badge("equator", "Crossed the Line", "Both hemispheres", "arrow.up.arrow.down.circle", input.crossedEquator ? 1 : 0, 1),
            badge("days-100", "Century Abroad", "100 travel days", "calendar", input.travelDays, 100),
            badge("days-365", "A Year Away", "365 travel days", "calendar.badge.clock", input.travelDays, 365),
            badge("trip-14", "Fortnight Out", "A 14-day trip", "suitcase", input.longestTripDays, 14),
            badge("trip-30", "Slow Traveller", "A 30-day trip", "tortoise", input.longestTripDays, 30),
            badge("week-3", "Border Hopper", "3 countries in 7 days", "figure.walk.motion", input.mostCountriesInAWeek, 3),
            badge("year-10", "Big Year", "10 countries in one year", "sparkles", input.bestYearCountries, 10),
            badge("schengen-10", "Schengen Sampler", "10 Schengen states", "star.circle", input.schengenCountries, 10),
            badge("wishlist-3", "Dreams Kept", "Visit 3 wishlist countries", "heart.circle", input.wishlistVisited, 3),
        ]
    }
}
