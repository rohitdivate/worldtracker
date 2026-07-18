import XCTest
@testable import WorldTrackerKit

final class CityDaysTests: XCTestCase {
    private func obs(
        _ city: String?, cc: String? = "CH", day: Int = 100,
        lat: Double = 47.37, lon: Double = 8.54, weight: Int = 1
    ) -> CityObservation {
        CityObservation(
            city: city, countryCode: cc, epochDay: day,
            latitude: lat, longitude: lon, weight: weight
        )
    }

    /// The same city on the same day from two sources is ONE day.
    func testDistinctDayCounting() {
        let result = CityDayAggregator.aggregate([
            obs("Zurich", day: 100, weight: 5),   // photo evidence
            obs("Zurich", day: 100, weight: 1),   // place visit, same day
            obs("Zurich", day: 101, weight: 1),
        ])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.days, 2)
    }

    /// Diacritic/case variants merge; the heaviest spelling wins display.
    func testDiacriticMergeAndDisplayName() {
        let result = CityDayAggregator.aggregate([
            obs("Zurich", day: 100, weight: 2),
            obs("Zürich", day: 101, weight: 7),
            obs("ZURICH", day: 102, weight: 1),
        ])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.days, 3)
        XCTAssertEqual(result.first?.name, "Zürich")
    }

    /// Same name in two countries stays separate.
    func testSameNameDifferentCountriesStaySeparate() {
        let result = CityDayAggregator.aggregate([
            obs("Springfield", cc: "US", day: 100, lat: 39.8, lon: -89.6),
            obs("Springfield", cc: "CA", day: 100, lat: 45.3, lon: -66.0),
        ])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.countryCode)), ["US", "CA"])
    }

    func testNilAndEmptyCitiesDropped() {
        let result = CityDayAggregator.aggregate([
            obs(nil), obs(""), obs("   "), obs("Basel", day: 200),
        ])
        XCTAssertEqual(result.map(\.name), ["Basel"])
    }

    /// The pin lands on the busiest cell, deterministically under ties.
    func testRepresentativeCoordinateIsMaxWeight() {
        let result = CityDayAggregator.aggregate([
            obs("Zurich", day: 100, lat: 47.30, lon: 8.50, weight: 2),
            obs("Zurich", day: 101, lat: 47.37, lon: 8.54, weight: 9),
            obs("Zurich", day: 102, lat: 47.40, lon: 8.60, weight: 1),
        ])
        XCTAssertEqual(result.first?.latitude, 47.37)
        XCTAssertEqual(result.first?.longitude, 8.54)

        // Tie on weight → later epochDay wins.
        let tied = CityDayAggregator.aggregate([
            obs("Bern", day: 100, lat: 46.9, lon: 7.4, weight: 3),
            obs("Bern", day: 105, lat: 46.95, lon: 7.45, weight: 3),
        ])
        XCTAssertEqual(tied.first?.latitude, 46.95)
    }

    /// Aggregate output is ranked by days desc, then name asc.
    func testAggregateRanking() {
        let result = CityDayAggregator.aggregate([
            obs("Basel", day: 1), obs("Basel", day: 2),
            obs("Zurich", day: 1), obs("Zurich", day: 2), obs("Zurich", day: 3),
            obs("Geneva", day: 1), obs("Geneva", day: 5),
        ])
        XCTAssertEqual(result.map(\.name), ["Zurich", "Basel", "Geneva"])
    }

    /// visible() honors the box, keeps ranking, and caps the count.
    func testVisibleFilterRankAndLimit() {
        let cities = CityDayAggregator.aggregate([
            obs("Zurich", day: 1), obs("Zurich", day: 2), obs("Zurich", day: 3),
            obs("Basel", day: 1, lat: 47.56, lon: 7.59), obs("Basel", day: 2, lat: 47.56, lon: 7.59),
            obs("Tokyo", cc: "JP", day: 1, lat: 35.68, lon: 139.76),
        ])
        let visible = CityDayAggregator.visible(
            cities,
            centerLatitude: 47.0, centerLongitude: 8.0,
            latitudeDelta: 4, longitudeDelta: 6,
            limit: 1
        )
        XCTAssertEqual(visible.map(\.name), ["Zurich"])

        let both = CityDayAggregator.visible(
            cities,
            centerLatitude: 47.0, centerLongitude: 8.0,
            latitudeDelta: 4, longitudeDelta: 6,
            limit: 12
        )
        XCTAssertEqual(both.map(\.name), ["Zurich", "Basel"])
    }

    /// A viewport straddling the antimeridian still finds cities across it.
    func testVisibleWrapsAntimeridian() {
        let cities = CityDayAggregator.aggregate([
            obs("Suva", cc: "FJ", day: 1, lat: -18.14, lon: 178.44),
            obs("Nuku'alofa", cc: "TO", day: 1, lat: -21.14, lon: -175.20),
        ])
        let visible = CityDayAggregator.visible(
            cities,
            centerLatitude: -19.0, centerLongitude: 179.0,
            latitudeDelta: 10, longitudeDelta: 14,
            limit: 12
        )
        XCTAssertEqual(Set(visible.map(\.countryCode)), ["FJ", "TO"])
    }

    /// A whole-globe span passes every longitude.
    func testVisibleFullSpanPassesAll() {
        let cities = CityDayAggregator.aggregate([
            obs("Zurich", day: 1),
            obs("Tokyo", cc: "JP", day: 1, lat: 35.68, lon: 139.76),
        ])
        let visible = CityDayAggregator.visible(
            cities,
            centerLatitude: 40.0, centerLongitude: 0.0,
            latitudeDelta: 180, longitudeDelta: 360,
            limit: 12
        )
        XCTAssertEqual(visible.count, 2)
    }
}
