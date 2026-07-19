import XCTest
@testable import WorldTrackerKit

final class YearInReviewTests: XCTestCase {
    private let jan1 = EpochDay.daysFromCivil(year: 2026, month: 1, day: 1)

    private func day(_ offset: Int, _ codes: [String], filled: Bool = false) -> ResolvedDay {
        ResolvedDay(
            day: jan1 + offset,
            countryCodes: codes,
            source: codes.isEmpty ? nil : .gps,
            isFilled: filled
        )
    }

    /// A year: 20 home days, a 9-day trip spanning ES→FR, 5 more home days,
    /// a 3-day DK trip.
    private func sampleYear() -> [ResolvedDay] {
        var days: [ResolvedDay] = []
        for i in 0..<20 { days.append(day(i, ["GB"])) }
        for i in 20..<24 { days.append(day(i, ["ES"])) }
        days.append(day(24, ["ES", "FR"]))
        for i in 25..<29 { days.append(day(i, ["FR"])) }
        for i in 29..<34 { days.append(day(i, ["GB"])) }
        for i in 34..<37 { days.append(day(i, ["DK"])) }
        return days
    }

    func testEmptyYearFailsMinimumData() {
        let stats = YearInReview.compute(
            year: 2026, days: [], homeCountry: "GB", priorCountryCodes: []
        )
        XCTAssertFalse(stats.meetsMinimumData)
        XCTAssertEqual(stats.countriesVisited, 0)
        XCTAssertNil(stats.longestTrip)
        XCTAssertNil(stats.busiestMonth)
    }

    func testHomeOnlyYearFailsMinimumData() {
        let days = (0..<30).map { day($0, ["GB"]) }
        let stats = YearInReview.compute(
            year: 2026, days: days, homeCountry: "GB", priorCountryCodes: ["GB"]
        )
        XCTAssertFalse(stats.meetsMinimumData)   // 1 country, 0 travel days
        XCTAssertEqual(stats.trackedDays, 30)
    }

    func testSampleYearBasics() {
        let stats = YearInReview.compute(
            year: 2026,
            days: sampleYear(),
            homeCountry: "GB",
            priorCountryCodes: ["GB", "ES"]
        )
        XCTAssertTrue(stats.meetsMinimumData)
        XCTAssertEqual(stats.countriesVisited, 4)
        XCTAssertEqual(stats.travelDays, 12)      // 9 ES/FR + 3 DK
        XCTAssertEqual(stats.topCountries.first?.code, "GB")

        // First visits exclude prior countries; order = first appearance.
        XCTAssertEqual(stats.firstVisits, ["FR", "DK"])
        XCTAssertEqual(stats.firstAppearanceOrder, ["GB", "ES", "FR", "DK"])
    }

    func testLongestTripSpansCountriesIncludingBorderDay() {
        let stats = YearInReview.compute(
            year: 2026, days: sampleYear(), homeCountry: "GB", priorCountryCodes: []
        )
        let trip = stats.longestTrip
        XCTAssertEqual(trip?.dayCount, 9)
        XCTAssertEqual(trip?.countryCodes, ["ES", "FR"])
        XCTAssertEqual(trip?.startDay, jan1 + 20)
        XCTAssertEqual(trip?.endDay, jan1 + 28)
    }

    func testBusiestMonth() {
        let stats = YearInReview.compute(
            year: 2026, days: sampleYear(), homeCountry: "GB", priorCountryCodes: []
        )
        // Trip days 20-28 are Jan 21-29; DK trip Feb 4-6 → January busiest.
        XCTAssertEqual(stats.busiestMonth?.month, 1)
        XCTAssertEqual(stats.busiestMonth?.travelDays, 9)
    }

    func testNomadNoHomeCountsAllTrackedAsTravel() {
        let days = (0..<15).map { day($0, ["TH"]) }
        let stats = YearInReview.compute(
            year: 2026, days: days, homeCountry: nil, priorCountryCodes: []
        )
        XCTAssertEqual(stats.travelDays, 15)
        XCTAssertEqual(stats.longestTrip?.dayCount, 15)
        XCTAssertTrue(stats.meetsMinimumData)
    }

    func testPlaceHighlightPrefersAwayFromHome() {
        let places = [
            PlaceVisitInput(name: "Local Café", city: "London", countryCode: "GB",
                            visitEpochDays: (0..<8).map { jan1 + $0 }),
            PlaceVisitInput(name: "La Boqueria", city: "Barcelona", countryCode: "ES",
                            visitEpochDays: [jan1 + 21, jan1 + 22]),
        ]
        let stats = YearInReview.compute(
            year: 2026, days: sampleYear(), homeCountry: "GB",
            priorCountryCodes: [], places: places
        )
        XCTAssertEqual(stats.mostVisitedPlace?.name, "La Boqueria")
        XCTAssertEqual(stats.mostVisitedPlace?.visitCount, 2)
    }

    func testPlaceHighlightFallsBackToHomeWhenNoAwayCandidate() {
        let places = [
            PlaceVisitInput(name: "Local Café", city: "London", countryCode: "GB",
                            visitEpochDays: (0..<8).map { jan1 + $0 })
        ]
        let stats = YearInReview.compute(
            year: 2026, days: sampleYear(), homeCountry: "GB",
            priorCountryCodes: [], places: places
        )
        XCTAssertEqual(stats.mostVisitedPlace?.name, "Local Café")
    }

    func testTrailingAwayRunClosesAtYearEnd() {
        var days = (0..<10).map { day($0, ["GB"]) }
        days += (10..<20).map { day($0, ["JP"]) }
        let stats = YearInReview.compute(
            year: 2026, days: days, homeCountry: "GB", priorCountryCodes: []
        )
        XCTAssertEqual(stats.longestTrip?.dayCount, 10)
        XCTAssertEqual(stats.longestTrip?.countryCodes, ["JP"])
    }

    /// The relocation year: US home Jan–Apr, then a move to the UK.
    /// Days living in the US must not read as travel; a US visit AFTER the
    /// move must.
    func testMidYearHomeMoveScenario() {
        let moveDay = jan1 + 120   // ~May 1
        let timeline = HomeTimeline(periods: [
            HomePeriod(startDay: nil, countryCode: "US"),
            HomePeriod(startDay: moveDay, countryCode: "GB"),
        ])

        var days: [ResolvedDay] = []
        for i in 0..<120 { days.append(day(i, ["US"])) }          // living in US
        for i in 120..<308 { days.append(day(i, ["GB"])) }        // living in UK
        for i in 308..<315 { days.append(day(i, ["US"])) }        // Nov 5–11 US visit
        for i in 315..<330 { days.append(day(i, ["GB"])) }

        let stats = YearInReview.compute(
            year: 2026, days: days, homeTimeline: timeline,
            priorCountryCodes: ["US"]
        )
        // Only the 7-day November visit is travel.
        XCTAssertEqual(stats.travelDays, 7)
        XCTAssertEqual(stats.longestTrip?.dayCount, 7)
        XCTAssertEqual(stats.longestTrip?.countryCodes, ["US"])
        // Busiest month is November (the visit), not the US-resident spring.
        XCTAssertEqual(stats.busiestMonth?.month, 11)
        // Display home = the year's dominant home (UK covers ~7 months).
        XCTAssertEqual(stats.homeCountry, "GB")
    }

    func testPlaceHighlightJudgedAgainstPerDayHome() {
        let moveDay = jan1 + 120
        let timeline = HomeTimeline(periods: [
            HomePeriod(startDay: nil, countryCode: "US"),
            HomePeriod(startDay: moveDay, countryCode: "GB"),
        ])
        var days: [ResolvedDay] = []
        for i in 0..<120 { days.append(day(i, ["US"])) }
        for i in 120..<300 { days.append(day(i, ["GB"])) }
        for i in 300..<307 { days.append(day(i, ["US"])) }

        // The old-life café: visited only while the US was home → not "away".
        let oldCafe = PlaceVisitInput(name: "Blue Bottle", city: "SF", countryCode: "US",
                                      visitEpochDays: [jan1 + 10, jan1 + 20, jan1 + 30])
        // Same country, but visited during the November trip → away.
        let tripSpot = PlaceVisitInput(name: "Katz's Deli", city: "NYC", countryCode: "US",
                                       visitEpochDays: [jan1 + 301, jan1 + 303])
        let stats = YearInReview.compute(
            year: 2026, days: days, homeTimeline: timeline,
            priorCountryCodes: [], places: [oldCafe, tripSpot]
        )
        XCTAssertEqual(stats.mostVisitedPlace?.name, "Katz's Deli")
    }
}
