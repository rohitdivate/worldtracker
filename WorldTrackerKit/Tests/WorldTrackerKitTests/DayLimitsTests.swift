import XCTest
@testable import WorldTrackerKit

final class DayLimitsTests: XCTestCase {
    private func epoch(_ year: Int, _ month: Int, _ day: Int) -> Int {
        EpochDay.daysFromCivil(year: year, month: month, day: day)
    }

    /// Resolved days over `range`; `blocks` paint codes onto sub-ranges and
    /// later blocks win. Unpainted days are unknown.
    private func ledger(
        _ range: ClosedRange<Int>, _ blocks: [(ClosedRange<Int>, [String])]
    ) -> [ResolvedDay] {
        var codes: [Int: [String]] = [:]
        for (span, value) in blocks {
            for day in span { codes[day] = value }
        }
        return range.map {
            ResolvedDay(day: $0, countryCodes: codes[$0] ?? [], source: nil, isFilled: false)
        }
    }

    // MARK: - Scope

    func testCountryScopeCountsAnyPresence() {
        let scope = DayLimitScope.country("FR")
        XCTAssertTrue(scope.counts(["FR"]))
        XCTAssertTrue(scope.counts(["GB", "FR"]))
        XCTAssertFalse(scope.counts(["GB"]))
        XCTAssertFalse(scope.counts([]))
    }

    func testSchengenScopeCoversMembersOnly() {
        let scope = DayLimitScope.schengen
        XCTAssertTrue(scope.counts(["ES"]))
        XCTAssertTrue(scope.counts(["GB", "CH"]))
        XCTAssertTrue(scope.counts(["BG"]))
        // EU but outside Schengen, and a non-EU neighbour.
        XCTAssertFalse(scope.counts(["IE"]))
        XCTAssertFalse(scope.counts(["CY"]))
        XCTAssertFalse(scope.counts(["GB"]))
        XCTAssertEqual(SchengenArea.members.count, 29)
    }

    /// An absence is a whole day away: a day that touches the country at
    /// either end of a trip is not one, and neither is a day with no data.
    func testOutsideScopeNeedsAWholeKnownDayAway() {
        let scope = DayLimitScope.outside("GB")
        XCTAssertTrue(scope.counts(["ES"]))
        XCTAssertTrue(scope.counts(["ES", "FR"]))
        XCTAssertFalse(scope.counts(["GB", "ES"]))
        XCTAssertFalse(scope.counts(["GB"]))
        XCTAssertFalse(scope.counts([]))
    }

    // MARK: - Windows

    func testRollingWindowEndsOnTheDay() {
        let day = epoch(2026, 6, 30)
        XCTAssertEqual(DayLimitWindow.rolling(days: 180).range(containing: day), (day - 179)...day)
    }

    func testCalendarYearWindow() {
        let window = DayLimitWindow.calendarYear.range(containing: epoch(2026, 3, 15))
        XCTAssertEqual(window, epoch(2026, 1, 1)...epoch(2026, 12, 31))
        // Leap year is 366 days long.
        XCTAssertEqual(DayLimitWindow.calendarYear.range(containing: epoch(2024, 2, 29)).count, 366)
    }

    func testUKTaxYearTurnsOverOnSixthOfApril() {
        let window = DayLimitWindow.yearStarting(month: 4, day: 6)
        XCTAssertEqual(
            window.range(containing: epoch(2026, 4, 5)),
            epoch(2025, 4, 6)...epoch(2026, 4, 5)
        )
        XCTAssertEqual(
            window.range(containing: epoch(2026, 4, 6)),
            epoch(2026, 4, 6)...epoch(2027, 4, 5)
        )
    }

    // MARK: - Schengen 90/180

    func testEmptyHistoryHasTheFullAllowance() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(), days: ledger((today - 200)...today, [((today - 200)...today, ["GB"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 0)
        XCTAssertEqual(status.remaining, 90)
        XCTAssertEqual(status.level, .clear)
        XCTAssertEqual(status.runwayDays, 90)
        XCTAssertNil(status.reliefDay)
        XCTAssertNil(status.daysUntilReset)
        XCTAssertFalse(status.countsToday)
        XCTAssertEqual(status.headline, "90 days left")
    }

    /// Ninety straight days, ending today: at the limit, no runway, and the
    /// first day back is 180 days after the first day in.
    func testNinetyStraightDaysIsExactlyTheLimit() {
        let today = epoch(2026, 6, 1)
        let first = today - 89
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger((today - 300)...today, [((today - 300)...today, ["GB"]), (first...today, ["FR"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 90)
        XCTAssertEqual(status.level, .close)
        XCTAssertEqual(status.headline, "At the limit")
        XCTAssertEqual(status.runwayDays, 0)
        XCTAssertEqual(status.reliefDay, first + 180)
        XCTAssertTrue(status.countsToday)
    }

    func testOverTheLimitReportsOverage() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger((today - 300)...today, [((today - 94)...today, ["IT"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 95)
        XCTAssertEqual(status.level, .over)
        XCTAssertEqual(status.overBy, 5)
        XCTAssertEqual(status.remaining, 0)
        XCTAssertEqual(status.headline, "5 days over")
        XCTAssertEqual(status.fraction, 1)
        XCTAssertNotNil(status.reliefDay)
    }

    /// Thirty days that ended 100 days ago. Staying from tomorrow, the old
    /// block rolls out of the window as the new one grows, so the full 90 is
    /// available again rather than 60.
    func testOldDaysRollOutDuringANewStay() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger(
                (today - 300)...today,
                [((today - 300)...today, ["GB"]), ((today - 129)...(today - 100), ["ES"])]
            ),
            asOf: today
        )
        XCTAssertEqual(status.used, 30)
        XCTAssertEqual(status.remaining, 60)
        XCTAssertEqual(status.runwayDays, 90)
    }

    /// Days older than the window don't count at all.
    func testDaysOutsideTheWindowAreIgnored() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger((today - 400)...today, [((today - 400)...(today - 180), ["DE"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 0)
    }

    func testBorderDaysCountForSchengen() {
        let today = epoch(2026, 6, 1)
        // Out on day 10, back on day 14: five days touch Schengen.
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger(
                (today - 30)...today,
                [
                    ((today - 30)...today, ["GB"]),
                    ((today - 10)...(today - 10), ["GB", "FR"]),
                    ((today - 9)...(today - 7), ["FR"]),
                    ((today - 6)...(today - 6), ["FR", "GB"]),
                ]
            ),
            asOf: today
        )
        XCTAssertEqual(status.used, 5)
    }

    // MARK: - Levels

    func testLevelThresholds() {
        let today = epoch(2026, 6, 1)
        func level(used: Int) -> DayLimitStatus.Level {
            DayLimitEvaluator.evaluate(
                rule: .schengen(),
                days: ledger((today - 200)...today, [((today - used + 1)...today, ["FR"])]),
                asOf: today
            ).level
        }
        XCTAssertEqual(level(used: 53), .clear)   // 58.9%
        XCTAssertEqual(level(used: 54), .watch)   // 60%
        XCTAssertEqual(level(used: 76), .watch)   // 84.4%
        XCTAssertEqual(level(used: 77), .close)   // 85.6%
        XCTAssertEqual(level(used: 90), .close)
        XCTAssertEqual(level(used: 91), .over)
    }

    // MARK: - Fixed windows

    func testCalendarYearRuleKnowsWhenItCannotBeExceeded() {
        let today = epoch(2026, 11, 1)
        let rule = DayLimitRule.calendarYear183(country: "ES", countryName: "Spain")
        let jan1 = epoch(2026, 1, 1)

        // 100 used, 60 days left in the year: 83 remaining can't be spent.
        let safe = DayLimitEvaluator.evaluate(
            rule: rule,
            days: ledger(jan1...today, [(jan1...today, ["GB"]), (jan1...(jan1 + 99), ["ES"])]),
            asOf: today
        )
        XCTAssertEqual(safe.used, 100)
        XCTAssertEqual(safe.daysUntilReset, 60)
        XCTAssertTrue(safe.isSafeUntilReset)
        XCTAssertNil(safe.reliefDay)

        // 150 used: 33 remaining, fewer than the 60 days left.
        let tight = DayLimitEvaluator.evaluate(
            rule: rule,
            days: ledger(jan1...today, [(jan1...today, ["GB"]), (jan1...(jan1 + 149), ["ES"])]),
            asOf: today
        )
        XCTAssertEqual(tight.remaining, 33)
        XCTAssertFalse(tight.isSafeUntilReset)
        XCTAssertEqual(tight.runwayDays, 33)
        XCTAssertEqual(tight.detail, "150 of 183 days · calendar year")
    }

    /// Last year's days never leak into this year's count.
    func testCalendarYearRuleResetsOnJanuaryFirst() {
        let today = epoch(2026, 1, 10)
        let status = DayLimitEvaluator.evaluate(
            rule: .calendarYear183(country: "ES", countryName: "Spain"),
            days: ledger(epoch(2025, 1, 1)...today, [(epoch(2025, 1, 1)...today, ["ES"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 10)
    }

    func testUKTaxYearCountsFromSixthOfApril() {
        let today = epoch(2026, 4, 10)
        let status = DayLimitEvaluator.evaluate(
            rule: .ukTaxYear(),
            days: ledger(epoch(2026, 1, 1)...today, [(epoch(2026, 1, 1)...today, ["GB"])]),
            asOf: today
        )
        // 6, 7, 8, 9, 10 April.
        XCTAssertEqual(status.used, 5)
        XCTAssertEqual(status.window.lowerBound, epoch(2026, 4, 6))
    }

    // MARK: - Absences

    /// A ten-day trip: the two travel days touch the UK, so eight absences.
    func testUKAbsencesExcludeTravelDays() {
        let today = epoch(2026, 6, 1)
        let out = today - 20
        let status = DayLimitEvaluator.evaluate(
            rule: .ukAbsences(),
            days: ledger(
                (today - 400)...today,
                [
                    ((today - 400)...today, ["GB"]),
                    (out...out, ["GB", "ES"]),
                    ((out + 1)...(out + 8), ["ES"]),
                    ((out + 9)...(out + 9), ["ES", "GB"]),
                ]
            ),
            asOf: today
        )
        XCTAssertEqual(status.used, 8)
        XCTAssertEqual(status.remaining, 172)
        XCTAssertFalse(status.countsToday)
    }

    // MARK: - Unknown days

    func testUnknownDaysAreReportedNotCounted() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger((today - 179)...today, [((today - 9)...today, ["FR"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 10)
        XCTAssertEqual(status.unknownDays, 170)
    }

    /// History shorter than the window: the missing days are simply outside
    /// what was asked about, not "unknown".
    func testShortHistoryDoesNotInventUnknownDays() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger((today - 9)...today, [((today - 9)...today, ["FR"])]),
            asOf: today
        )
        XCTAssertEqual(status.used, 10)
        XCTAssertEqual(status.unknownDays, 0)
    }

    func testNoDaysAtAllIsAllClear() {
        let status = DayLimitEvaluator.evaluate(rule: .schengen(), days: [], asOf: 20_000)
        XCTAssertEqual(status.used, 0)
        XCTAssertEqual(status.runwayDays, 90)
    }

    // MARK: - Floors

    func testReachAtLeastGoal() {
        let today = epoch(2026, 6, 1)
        var rule = DayLimitRule.calendarYear183(country: "PT", countryName: "Portugal")
        rule.goal = .reachAtLeast
        let jan1 = epoch(2026, 1, 1)

        let building = DayLimitEvaluator.evaluate(
            rule: rule, days: ledger(jan1...today, [(jan1...(jan1 + 99), ["PT"])]), asOf: today
        )
        XCTAssertEqual(building.level, .building)
        XCTAssertEqual(building.headline, "83 days to go")
        XCTAssertNil(building.runwayDays)

        let reached = DayLimitEvaluator.evaluate(
            rule: rule,
            days: ledger(jan1...epoch(2026, 12, 1), [(jan1...(jan1 + 199), ["PT"])]),
            asOf: epoch(2026, 12, 1)
        )
        XCTAssertEqual(reached.level, .reached)
        XCTAssertEqual(reached.headline, "Reached")
    }

    // MARK: - Planning

    /// Arriving in 30 days with 60 recent days on the clock: by then some
    /// have rolled off, and more roll off during the stay.
    func testMaxStayForAFutureArrival() {
        let today = epoch(2026, 6, 1)
        let days = ledger(
            (today - 300)...today,
            [((today - 300)...today, ["GB"]), ((today - 59)...today, ["FR"])]
        )
        // Tomorrow: 60 used, 30 left, nothing rolls off in time.
        XCTAssertEqual(
            DayLimitEvaluator.maxStay(rule: .schengen(), days: days, asOf: today, entryDay: today + 1),
            30
        )
        // Arriving the day the oldest day leaves the window: one more fits
        // for every one that drops, so the stay runs until the block is gone.
        let later = DayLimitEvaluator.maxStay(
            rule: .schengen(), days: days, asOf: today, entryDay: today + 121
        )
        XCTAssertEqual(later, 90)
    }

    func testLimitAsLongAsTheWindowHasNoCeiling() {
        let rule = DayLimitRule(
            name: "Always fine", scope: .country("GB"), window: .rolling(days: 30), limit: 30
        )
        let status = DayLimitEvaluator.evaluate(rule: rule, days: [], asOf: 20_000)
        XCTAssertNil(status.runwayDays)
    }

    // MARK: - Text and coding

    func testSingularHeadline() {
        let today = epoch(2026, 6, 1)
        let status = DayLimitEvaluator.evaluate(
            rule: .schengen(),
            days: ledger((today - 200)...today, [((today - 88)...today, ["FR"])]),
            asOf: today
        )
        XCTAssertEqual(status.headline, "1 day left")
    }

    func testRuleRoundTripsThroughJSON() throws {
        let rules: [DayLimitRule] = [
            .schengen(), .ukAbsences(), .ukTaxYear(),
            .calendarYear183(country: "ES", countryName: "Spain"),
        ]
        let data = try JSONEncoder().encode(rules)
        XCTAssertEqual(try JSONDecoder().decode([DayLimitRule].self, from: data), rules)
    }

    func testWindowLabels() {
        XCTAssertEqual(DayLimitRule.schengen().windowLabel, "any 180 days")
        XCTAssertEqual(DayLimitRule.ukTaxYear().windowLabel, "year from 6 Apr")
    }
}
