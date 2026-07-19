import XCTest
@testable import WorldTrackerKit

final class HomeTimelineTests: XCTestCase {
    private let moveDay = EpochDay.daysFromCivil(year: 2019, month: 3, day: 15)

    private var usThenUK: HomeTimeline {
        HomeTimeline(periods: [
            HomePeriod(startDay: nil, countryCode: "US"),
            HomePeriod(startDay: moveDay, countryCode: "GB"),
        ])
    }

    func testHomeOnBoundaries() {
        XCTAssertEqual(usThenUK.home(on: moveDay - 1), "US")
        XCTAssertEqual(usThenUK.home(on: moveDay), "GB")
        XCTAssertEqual(usThenUK.home(on: moveDay + 1), "GB")
        XCTAssertEqual(usThenUK.home(on: moveDay - 10_000), "US")
        XCTAssertEqual(usThenUK.current, "GB")
    }

    func testEmptyAndNoOpenStart() {
        XCTAssertNil(HomeTimeline.empty.home(on: 0))
        XCTAssertNil(HomeTimeline.empty.current)

        // A timeline that starts mid-history: no home before the first period.
        let late = HomeTimeline(periods: [HomePeriod(startDay: moveDay, countryCode: "GB")])
        XCTAssertNil(late.home(on: moveDay - 1))
        XCTAssertEqual(late.home(on: moveDay), "GB")
    }

    func testSingleSeedActsAsConstant() {
        let single = HomeTimeline.single("GB")
        XCTAssertEqual(single.home(on: 0), "GB")
        XCTAssertEqual(single.home(on: 1_000_000), "GB")
        XCTAssertEqual(single.current, "GB")
        XCTAssertTrue(HomeTimeline.single(nil).isEmpty)
    }

    func testNormalizationSortsAndMergesDuplicates() {
        let messy = HomeTimeline(periods: [
            HomePeriod(startDay: moveDay, countryCode: "GB"),
            HomePeriod(startDay: nil, countryCode: "US"),
            HomePeriod(startDay: moveDay + 100, countryCode: "GB"),  // redundant
        ])
        XCTAssertEqual(messy.periods.count, 2)
        XCTAssertEqual(messy, usThenUK)
    }

    func testDominantHomeMajorityAndTies() {
        let jan1 = EpochDay.daysFromCivil(year: 2019, month: 1, day: 1)
        let dec31 = EpochDay.daysFromCivil(year: 2019, month: 12, day: 31)
        // Moved mid-March: GB covers ~9.5 months of 2019.
        XCTAssertEqual(usThenUK.dominantHome(in: jan1...dec31), "GB")
        // A range fully inside the US period.
        XCTAssertEqual(usThenUK.dominantHome(in: (jan1 - 400)...(jan1 - 300)), "US")
        // Perfect tie → the later period wins.
        let tie = usThenUK.dominantHome(in: (moveDay - 5)...(moveDay + 4))
        XCTAssertEqual(tie, "GB")
    }

    func testCacheKeyDistinguishesTimelines() {
        XCTAssertNotEqual(usThenUK.cacheKey, HomeTimeline.single("GB").cacheKey)
        XCTAssertNotEqual(usThenUK.cacheKey, HomeTimeline.single("US").cacheKey)
        XCTAssertEqual(HomeTimeline.empty.cacheKey, "-")
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(usThenUK)
        let decoded = try JSONDecoder().decode(HomeTimeline.self, from: data)
        XCTAssertEqual(decoded, usThenUK)
    }
}

/// Per-day-home behavior of the resolver's derived views.
final class HomeTimelineStatsTests: XCTestCase {
    private let moveDay = 18_000

    private var usThenUK: HomeTimeline {
        HomeTimeline(periods: [
            HomePeriod(startDay: nil, countryCode: "US"),
            HomePeriod(startDay: moveDay, countryCode: "GB"),
        ])
    }

    private func day(_ d: Int, _ codes: [String]) -> ResolvedDay {
        ResolvedDay(day: d, countryCodes: codes, source: codes.isEmpty ? nil : .gps, isFilled: false)
    }

    func testStatsMidRangeHomeMoveTravelDays() {
        // 5 US days while US was home, 3 US days after moving to the UK,
        // 4 GB days after the move.
        var days: [ResolvedDay] = []
        for d in (moveDay - 5)..<moveDay { days.append(day(d, ["US"])) }
        for d in moveDay..<(moveDay + 3) { days.append(day(d, ["US"])) }
        for d in (moveDay + 3)..<(moveDay + 7) { days.append(day(d, ["GB"])) }

        let stats = DayLedgerResolver.stats(for: days, homeTimeline: usThenUK)
        // Only the 3 post-move US days are travel.
        XCTAssertEqual(stats.travelDays, 3)
        XCTAssertEqual(stats.daysPerCountry["US"], 8)
        XCTAssertEqual(stats.daysPerCountry["GB"], 4)
    }

    func testLegacyOverloadMatchesSingleTimeline() {
        let days = (0..<10).map { day($0, $0 < 6 ? ["GB"] : ["FR"]) }
        XCTAssertEqual(
            DayLedgerResolver.stats(for: days, home: "GB"),
            DayLedgerResolver.stats(for: days, homeTimeline: .single("GB"))
        )
    }

    func testTripSegmentsExcludeHomeRuns() {
        let home = HomeTimeline.single("GB")
        var days: [ResolvedDay] = []
        for d in 0..<5 { days.append(day(d, ["GB"])) }
        for d in 5..<9 { days.append(day(d, ["ES"])) }
        for d in 9..<12 { days.append(day(d, ["GB"])) }

        let trips = DayLedgerResolver.tripSegments(from: days, homeTimeline: home)
        XCTAssertEqual(trips.count, 1)
        XCTAssertEqual(trips[0].countryCode, "ES")
        XCTAssertEqual(trips[0].startDay, 5)
        XCTAssertEqual(trips[0].endDay, 8)
    }

    func testTripSegmentsBorderDayKeepsForeignCountry() {
        let home = HomeTimeline.single("GB")
        var days: [ResolvedDay] = []
        days.append(day(0, ["GB"]))
        days.append(day(1, ["GB", "FR"]))   // crossing day
        days.append(day(2, ["FR"]))

        let trips = DayLedgerResolver.tripSegments(from: days, homeTimeline: home)
        XCTAssertEqual(trips.count, 1)
        XCTAssertEqual(trips[0].countryCode, "FR")
        XCTAssertEqual(trips[0].startDay, 1)
        XCTAssertEqual(trips[0].endDay, 2)
    }

    func testTripSegmentsSplitAtHomeMove() {
        // Living in the US continuously; home flips to GB at moveDay.
        let days = ((moveDay - 4)..<(moveDay + 4)).map { day($0, ["US"]) }
        let trips = DayLedgerResolver.tripSegments(from: days, homeTimeline: usThenUK)
        XCTAssertEqual(trips.count, 1)
        XCTAssertEqual(trips[0].countryCode, "US")
        XCTAssertEqual(trips[0].startDay, moveDay)   // trip starts when US stopped being home
        XCTAssertEqual(trips[0].endDay, moveDay + 3)
    }

    func testTripSegmentsEmptyTimelineMatchesSegments() {
        let days = (0..<6).map { day($0, $0 < 3 ? ["GB"] : ["FR"]) }
        XCTAssertEqual(
            DayLedgerResolver.tripSegments(from: days, homeTimeline: .empty),
            DayLedgerResolver.segments(from: days)
        )
    }

    func testIsHomeStayStraddlingMove() {
        let seg = TripSegment(countryCode: "US", startDay: moveDay - 4, endDay: moveDay + 2)
        XCTAssertTrue(DayLedgerResolver.isHomeStay(seg, timeline: usThenUK))
        let post = TripSegment(countryCode: "US", startDay: moveDay + 1, endDay: moveDay + 5)
        XCTAssertFalse(DayLedgerResolver.isHomeStay(post, timeline: usThenUK))
    }
}
