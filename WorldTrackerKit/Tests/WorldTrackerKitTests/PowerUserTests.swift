import XCTest
@testable import WorldTrackerKit

final class PowerUserTests: XCTestCase {
    private func ledger(
        _ range: ClosedRange<Int>, _ blocks: [(ClosedRange<Int>, [String])], filled: Set<Int> = []
    ) -> [ResolvedDay] {
        var codes: [Int: [String]] = [:]
        for (span, value) in blocks { for day in span { codes[day] = value } }
        return range.map {
            ResolvedDay(day: $0, countryCodes: codes[$0] ?? [], source: nil, isFilled: filled.contains($0))
        }
    }

    // MARK: - Plans

    func testPlanNormalisesItsDates() {
        let plan = PlannedTrip(countryCode: "FR", startDay: 20, endDay: 10)
        XCTAssertEqual(plan.startDay, 10)
        XCTAssertEqual(plan.dayCount, 11)
    }

    func testUpcomingDropsFinishedPlans() {
        let plans = [
            PlannedTrip(id: "old", countryCode: "FR", startDay: 1, endDay: 5),
            PlannedTrip(id: "live", countryCode: "ES", startDay: 8, endDay: 12),
            PlannedTrip(id: "next", countryCode: "IT", startDay: 30, endDay: 34),
        ]
        XCTAssertEqual(TripPlans.upcoming(plans, today: 10).map(\.id), ["live", "next"])
        XCTAssertEqual(TripPlans.upcoming(plans, today: 12).map(\.id), ["next"])
    }

    /// Travel days touch home; the days between trips are spent there.
    func testProjectionAddsHomeOnTravelDaysAndBetweenTrips() {
        let days = TripPlans.projectedDays(
            plans: [
                PlannedTrip(countryCode: "FR", startDay: 12, endDay: 14),
                PlannedTrip(countryCode: "ES", startDay: 17, endDay: 18),
            ],
            after: 10, home: "GB"
        )
        XCTAssertEqual(days.map(\.day), Array(11...18))
        XCTAssertEqual(days.map(\.countryCodes), [
            ["GB"], ["GB", "FR"], ["FR"], ["GB", "FR"], ["GB"], ["GB"], ["GB", "ES"], ["GB", "ES"],
        ])
    }

    /// Back-to-back plans are a direct hop: no touch of home in the middle.
    func testDirectHopBetweenPlansDoesNotTouchHome() {
        let days = TripPlans.projectedDays(
            plans: [
                PlannedTrip(countryCode: "FR", startDay: 12, endDay: 14),
                PlannedTrip(countryCode: "IT", startDay: 15, endDay: 16),
            ],
            after: 10, home: "GB"
        )
        XCTAssertEqual(days.map(\.countryCodes), [
            ["GB"], ["GB", "FR"], ["FR"], ["FR"], ["IT"], ["GB", "IT"],
        ])
    }

    func testProjectionWithoutHomeLeavesGapsUnknown() {
        let days = TripPlans.projectedDays(
            plans: [PlannedTrip(countryCode: "FR", startDay: 13, endDay: 13)], after: 10, home: nil
        )
        XCTAssertEqual(days.map(\.countryCodes), [[], [], ["FR"]])
        XCTAssertEqual(TripPlans.projectedDays(plans: [], after: 10, home: "GB"), [])
    }

    /// A trip under way: only its future days are projected, and today's
    /// departure is not replayed.
    func testOngoingPlanProjectsOnlyTheFuture() {
        let days = TripPlans.projectedDays(
            plans: [PlannedTrip(countryCode: "FR", startDay: 8, endDay: 12)], after: 10, home: "GB"
        )
        XCTAssertEqual(days.map(\.countryCodes), [["FR"], ["GB", "FR"]])
    }

    // MARK: - Forecast

    func testForecastFindsThePeakAndTheBreach() {
        let today = 1000
        // 80 Schengen days ending today, then a 15-day trip from day 1010.
        let history = ledger((today - 300)...today, [
            ((today - 300)...today, ["GB"]), ((today - 79)...today, ["FR"]),
        ])
        let planned = TripPlans.projectedDays(
            plans: [PlannedTrip(countryCode: "ES", startDay: today + 10, endDay: today + 24)],
            after: today, home: "GB"
        )
        let forecast = DayLimitEvaluator.forecast(
            rule: .schengen(), days: history, planned: planned, asOf: today
        )
        XCTAssertEqual(forecast?.endDay, today + 24)
        // 80 + 15 with nothing rolling off yet (the oldest day is 79 back).
        XCTAssertEqual(forecast?.peakUsed, 95)
        XCTAssertEqual(forecast?.crossingDay, today + 20)   // the 91st day
        XCTAssertEqual(forecast?.level, .over)
    }

    func testForecastWithinTheLimit() {
        let today = 1000
        let history = ledger((today - 300)...today, [((today - 300)...today, ["GB"])])
        let planned = TripPlans.projectedDays(
            plans: [PlannedTrip(countryCode: "IT", startDay: today + 5, endDay: today + 11)],
            after: today, home: "GB"
        )
        let forecast = DayLimitEvaluator.forecast(
            rule: .schengen(), days: history, planned: planned, asOf: today
        )
        XCTAssertEqual(forecast?.peakUsed, 7)
        XCTAssertEqual(forecast?.peakDay, today + 11)
        XCTAssertNil(forecast?.crossingDay)
        XCTAssertEqual(forecast?.level, .clear)
        XCTAssertEqual(forecast?.usedAtEnd, 7)
    }

    /// Travel days touch the UK, so a seven-day trip is five absences.
    func testForecastForAbsencesSkipsTravelDays() {
        let today = 1000
        let history = ledger((today - 400)...today, [((today - 400)...today, ["GB"])])
        let planned = TripPlans.projectedDays(
            plans: [PlannedTrip(countryCode: "IT", startDay: today + 5, endDay: today + 11)],
            after: today, home: "GB"
        )
        let forecast = DayLimitEvaluator.forecast(
            rule: .ukAbsences(), days: history, planned: planned, asOf: today
        )
        XCTAssertEqual(forecast?.peakUsed, 5)
    }

    func testNoPlansNoForecast() {
        XCTAssertNil(DayLimitEvaluator.forecast(rule: .schengen(), days: [], planned: [], asOf: 100))
    }

    func testForecastForAFloorReportsWhenItIsReached() {
        let today = EpochDay.daysFromCivil(year: 2026, month: 6, day: 1)
        var rule = DayLimitRule.calendarYear183(country: "PT", countryName: "Portugal")
        rule.goal = .reachAtLeast
        rule.limit = 10
        let jan1 = EpochDay.daysFromCivil(year: 2026, month: 1, day: 1)
        let history = ledger(jan1...today, [(jan1...today, ["GB"]), (jan1...(jan1 + 5), ["PT"])])
        let planned = TripPlans.projectedDays(
            plans: [PlannedTrip(countryCode: "PT", startDay: today + 2, endDay: today + 9)],
            after: today, home: "GB"
        )
        let forecast = DayLimitEvaluator.forecast(rule: rule, days: history, planned: planned, asOf: today)
        XCTAssertEqual(forecast?.crossingDay, today + 5)   // 6 + 4 = 10
        XCTAssertEqual(forecast?.level, .reached)
    }

    // MARK: - History

    func testPeakIsTheHighestRollingCount() {
        let today = 1000
        // 40 days long ago, 25 days recently: the old block is the peak.
        let days = ledger(0...today, [
            (0...today, ["GB"]), (100...139, ["FR"]), ((today - 30)...(today - 6), ["ES"]),
        ])
        let peak = DayLimitEvaluator.peak(rule: .schengen(), days: days, asOf: today)
        XCTAssertEqual(peak?.used, 40)
        // The window still holds all 40 until day 100 + 179.
        XCTAssertEqual(peak?.day, 279)
        XCTAssertNil(DayLimitEvaluator.peak(rule: .ukTaxYear(), days: days, asOf: today))
        XCTAssertNil(DayLimitEvaluator.peak(rule: .schengen(), days: [], asOf: today))
    }

    func testPastWindowsListEachTaxYear() {
        func e(_ y: Int, _ m: Int, _ d: Int) -> Int { EpochDay.daysFromCivil(year: y, month: m, day: d) }
        let today = e(2026, 6, 1)
        let start = e(2024, 5, 1)
        // Home all along, with 30 days abroad in each of two tax years.
        let days = ledger(start...today, [
            (start...today, ["GB"]),
            (e(2024, 7, 1)...e(2024, 7, 30), ["ES"]),
            (e(2025, 9, 1)...e(2025, 9, 30), ["IT"]),
        ])
        let windows = DayLimitEvaluator.pastWindows(rule: .ukTaxYear(), days: days, asOf: today)
        XCTAssertEqual(windows.count, 3)
        XCTAssertTrue(windows[0].isCurrent)
        XCTAssertEqual(windows[0].window.lowerBound, e(2026, 4, 6))
        XCTAssertEqual(windows[0].used, today - e(2026, 4, 6) + 1)
        XCTAssertEqual(windows[1].used, 365 - 30)
        // The first year only has data from 1 May 2024.
        XCTAssertEqual(windows[2].used, e(2025, 4, 5) - start + 1 - 30)
        XCTAssertFalse(windows[2].isCurrent)
        XCTAssertEqual(DayLimitEvaluator.pastWindows(rule: .schengen(), days: days, asOf: today), [])
    }

    // MARK: - Report

    func testStretchesAreUnbrokenCountedRuns() {
        let days = ledger(0...40, [
            (0...40, ["GB"]),
            (5...5, ["GB", "FR"]), (6...8, ["FR"]), (9...9, ["FR", "GB"]),
            (20...22, ["ES"]),
        ])
        let stretches = DayLimitEvaluator.stretches(rule: .schengen(), days: days, in: 0...40)
        XCTAssertEqual(stretches.map(\.startDay), [20, 5])        // newest first
        XCTAssertEqual(stretches[1].endDay, 9)
        XCTAssertEqual(stretches[1].days, 5)
        XCTAssertEqual(stretches[1].countryCodes, ["GB", "FR"])
        XCTAssertEqual(stretches[0].countryCodes, ["ES"])

        // Absences: only the whole days away.
        let absences = DayLimitEvaluator.stretches(rule: .ukAbsences(), days: days, in: 0...40)
        XCTAssertEqual(absences.map(\.days), [3, 3])
        // The range clips.
        XCTAssertEqual(
            DayLimitEvaluator.stretches(rule: .schengen(), days: days, in: 7...21).map(\.days), [2, 3]
        )
    }

    func testAnUnknownDaySplitsAStretch() {
        let days = ledger(0...9, [(0...3, ["FR"]), (5...9, ["FR"])])
        XCTAssertEqual(
            DayLimitEvaluator.stretches(rule: .schengen(), days: days, in: 0...9).map(\.days), [5, 4]
        )
    }

    func testReportCSV() {
        let csv = DayLimitReport.csv(
            rule: .schengen(),
            stretches: [
                CountedStretch(startDay: 20_500, endDay: 20_502, countryCodes: ["ES"]),
                CountedStretch(startDay: 20_454, endDay: 20_458, countryCodes: ["GB", "FR"]),
            ]
        )
        XCTAssertEqual(csv, """
            rule,first_day,last_day,days,countries
            "Schengen 90/180",2026-01-01,2026-01-05,5,GB|FR
            "Schengen 90/180",2026-02-16,2026-02-18,3,ES

            """)
    }

    // MARK: - Audit

    func testCoverageSplitsEvidencedInferredAndUnknown() {
        let days = ledger(0...9, [(0...6, ["GB"])], filled: [2, 3])
        let coverage = DayAudit.coverage(days)
        XCTAssertEqual(coverage.evidenced, 5)
        XCTAssertEqual(coverage.inferred, 2)
        XCTAssertEqual(coverage.unknown, 3)
        XCTAssertEqual(coverage.evidencedShare, 0.5, accuracy: 1e-9)
        XCTAssertEqual(DayAudit.coverage([]).evidencedShare, 0)
    }

    func testRunsGroupByKindAndAssumedCountry() {
        // 0-1 GB, 2-3 inferred GB, 4 inferred FR, 5 FR, 6-8 unknown, 9 GB
        let days = ledger(0...9, [(0...3, ["GB"]), (4...5, ["FR"]), (9...9, ["GB"])], filled: [2, 3, 4])
        let runs = DayAudit.runs(days)
        XCTAssertEqual(runs.map(\.startDay), [6, 4, 2])
        XCTAssertEqual(runs.map(\.kind), [.unknown, .inferred, .inferred])
        XCTAssertEqual(runs.map(\.days), [3, 1, 2])
        XCTAssertEqual(runs.map(\.assumedCode), [nil, "FR", "GB"])
        XCTAssertEqual(DayAudit.runs(ledger(0...3, [(0...3, ["GB"])])), [])
    }

    // MARK: - Backup

    private func archive() -> BackupArchive {
        BackupArchive(
            exportedDay: 20_700,
            facts: [
                .init(day: 1, countryCode: "GB", source: "gps", confidence: 1, evidenceCount: 4, firstSeen: 10, lastSeen: 20),
                .init(day: 1, countryCode: "FR", source: "manual", confidence: 1),
                .init(day: 2, countryCode: "FR", source: "photo", confidence: 0.8, scanGeneration: 3),
            ],
            annotations: [
                .init(day: 1, isCleared: false, note: "Eurostar"),
                .init(day: 5, isCleared: true, note: nil),
                .init(day: 6, isCleared: false, note: ""),
            ],
            homeTimeline: .single("GB"),
            gapFillMode: "short",
            gapFillMaxDays: 3,
            limitRules: [DayLimitRule(id: "s", name: "Schengen", scope: .schengen, window: .rolling(days: 180), limit: 90)],
            wishlist: ["JP", "PE"],
            plans: [PlannedTrip(id: "p", countryCode: "IT", startDay: 30, endDay: 34)]
        )
    }

    func testArchiveRoundTrips() throws {
        let original = archive()
        XCTAssertEqual(try BackupArchive.decode(original.encoded()), original)
    }

    func testDecodeRejectsNewerAndGarbage() throws {
        var newer = archive()
        newer.version = BackupArchive.currentVersion + 1
        XCTAssertThrowsError(try BackupArchive.decode(newer.encoded())) {
            XCTAssertEqual($0 as? BackupArchive.BackupError, .newerVersion(BackupArchive.currentVersion + 1))
        }
        XCTAssertThrowsError(try BackupArchive.decode(Data("not json".utf8))) {
            XCTAssertEqual($0 as? BackupArchive.BackupError, .unreadable)
        }
    }

    func testMergeIntoAnEmptyInstallTakesEverything() {
        let plan = BackupMergePlan.plan(
            archive: archive(), existingFacts: [], existingAnnotationDays: [],
            existingRuleIDs: [], existingWishlist: [], existingPlanIDs: [], hasHome: false
        )
        XCTAssertEqual(plan.facts.count, 3)
        // The empty annotation carries nothing and is dropped.
        XCTAssertEqual(plan.annotations.map(\.day), [1, 5])
        XCTAssertEqual(plan.rules.count, 1)
        XCTAssertEqual(plan.wishlist, ["JP", "PE"])
        XCTAssertEqual(plan.plans.count, 1)
        XCTAssertTrue(plan.adoptsProfile)
        XCTAssertFalse(plan.isEmpty)
    }

    /// Restoring twice, or onto a device that already has the data, adds
    /// nothing and leaves the device's own settings alone.
    func testMergeOnlyAddsWhatIsMissing() {
        let source = archive()
        let plan = BackupMergePlan.plan(
            archive: source,
            existingFacts: [source.facts[0].key, source.facts[2].key],
            existingAnnotationDays: [1],
            existingRuleIDs: ["s"],
            existingWishlist: ["JP"],
            existingPlanIDs: ["p"],
            hasHome: true
        )
        XCTAssertEqual(plan.facts.map(\.source), ["manual"])
        XCTAssertEqual(plan.annotations.map(\.day), [5])
        XCTAssertEqual(plan.rules, [])
        XCTAssertEqual(plan.wishlist, ["PE"])
        XCTAssertEqual(plan.plans, [])
        XCTAssertFalse(plan.adoptsProfile)

        let again = BackupMergePlan.plan(
            archive: source,
            existingFacts: Set(source.facts.map(\.key)),
            existingAnnotationDays: [1, 5],
            existingRuleIDs: ["s"], existingWishlist: ["JP", "PE"], existingPlanIDs: ["p"], hasHome: true
        )
        XCTAssertTrue(again.isEmpty)
    }

    func testDuplicateFactsInsideAnArchiveCollapse() {
        var source = archive()
        source.facts.append(source.facts[0])
        let plan = BackupMergePlan.plan(
            archive: source, existingFacts: [], existingAnnotationDays: [],
            existingRuleIDs: [], existingWishlist: [], existingPlanIDs: [], hasHome: true
        )
        XCTAssertEqual(plan.facts.count, 3)
    }
}
