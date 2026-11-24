import XCTest
@testable import WorldTrackerKit

final class TripEditPlannerTests: XCTestCase {
    /// Verdict lookup backed by a dictionary; unknown days resolve empty,
    /// exactly like single-day resolution of a gap-filled or cleared day.
    private func codes(_ table: [Int: [String]]) -> (Int) -> [String] {
        { table[$0] ?? [] }
    }

    // MARK: - Bucketing

    func testGrowOnlyEditRemovesNothing() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 5...8,
            keeping: 3...10,
            resolvedCodes: codes([5: ["FR"], 6: ["FR"], 7: ["FR"], 8: ["FR"]])
        )
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.countryCode, "FR")
    }

    func testShrinkTailBucketsSoloBorderAndEmptyDays() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...10,
            keeping: 1...7,
            resolvedCodes: codes([8: ["FR"], 9: ["FR", "ES"], 10: []])
        )
        XCTAssertEqual(plan.clearDays, [8, 10])
        XCTAssertEqual(plan.overrideDays, [.init(day: 9, countryCodes: ["ES"])])
    }

    func testShrinkHeadRemovesLeadingDaysOnly() {
        let plan = TripEditPlanner.plan(
            removingCountry: "JP",
            from: 1...10,
            keeping: 4...10,
            resolvedCodes: codes([1: ["JP"], 2: ["JP"], 3: ["JP"], 4: ["JP"]])
        )
        XCTAssertEqual(plan.clearDays, [1, 2, 3])
        XCTAssertTrue(plan.overrideDays.isEmpty)
    }

    func testPartialOverlapMoveRemovesOnlyTheLeftBehindDays() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...10,
            keeping: 6...15,
            resolvedCodes: codes([
                1: ["FR"], 2: ["FR"], 3: ["FR"], 4: ["FR"], 5: ["FR"],
                6: ["FR"], 7: ["FR"], 8: ["FR"], 9: ["FR"], 10: ["FR"],
            ])
        )
        XCTAssertEqual(plan.clearDays, [1, 2, 3, 4, 5])
        XCTAssertTrue(plan.overrideDays.isEmpty)
    }

    func testDisjointMoveRemovesTheEntireOriginalRange() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...5,
            keeping: 11...15,
            resolvedCodes: codes([1: ["FR"], 2: ["FR"], 3: ["FR"], 4: ["FR"], 5: ["FR"]])
        )
        XCTAssertEqual(plan.clearDays, [1, 2, 3, 4, 5])
    }

    func testBorderDayKeepsSurvivorsInResolverOrder() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 10...10,
            keeping: nil,
            resolvedCodes: codes([10: ["ES", "FR", "IT"]])
        )
        XCTAssertEqual(plan.overrideDays, [.init(day: 10, countryCodes: ["ES", "IT"])])
        XCTAssertTrue(plan.clearDays.isEmpty)
    }

    func testDayWithoutTheTripCountryIsLeftUntouched() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...3,
            keeping: 1...1,
            resolvedCodes: codes([1: ["FR"], 2: ["ES"], 3: ["FR"]])
        )
        XCTAssertEqual(plan.clearDays, [3])
        XCTAssertTrue(plan.overrideDays.isEmpty)
    }

    func testAlreadyClearedDayClearsAgainIdempotently() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 4...4,
            keeping: nil,
            resolvedCodes: codes([:])
        )
        XCTAssertEqual(plan.clearDays, [4])
    }

    func testDeletionModeBucketsEveryDay() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...4,
            keeping: nil,
            resolvedCodes: codes([1: ["FR"], 2: ["FR", "ES"], 3: [], 4: ["FR"]])
        )
        XCTAssertEqual(plan.clearDays, [1, 3, 4])
        XCTAssertEqual(plan.overrideDays, [.init(day: 2, countryCodes: ["ES"])])
    }

    func testOutputsAreAscending() {
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...6,
            keeping: nil,
            resolvedCodes: codes([
                1: ["FR"], 2: ["FR", "ES"], 3: ["FR"],
                4: ["FR", "IT"], 5: ["FR"], 6: ["FR"],
            ])
        )
        XCTAssertEqual(plan.clearDays, plan.clearDays.sorted())
        XCTAssertEqual(plan.overrideDays.map(\.day), plan.overrideDays.map(\.day).sorted())
    }

    // MARK: - End-to-end scenarios (planner output → write-side simulation
    // → resolver): the proof that edited dates actually stick.

    private func fact(
        _ day: Int, _ code: String, _ source: FactSource,
        confidence: Double = 1.0, evidence: Int = 1
    ) -> CountryFactInput {
        CountryFactInput(day: day, countryCode: code, source: source, confidence: confidence, evidenceCount: evidence)
    }

    /// What EditService.replaceTrip writes, mirrored for the pure resolver:
    /// automatic facts survive; the new range gets manual facts; plan clear
    /// days get cleared annotations; plan override days get survivor manual
    /// facts.
    private func simulateReplace(
        automatic: [CountryFactInput],
        newCountry: String,
        newRange: ClosedRange<Int>?,
        plan: TripEditPlan
    ) -> (facts: [CountryFactInput], annotations: [DayAnnotationInput]) {
        var facts = automatic
        if let newRange {
            for day in newRange {
                facts.append(fact(day, newCountry, .manual))
            }
        }
        for override in plan.overrideDays {
            for code in override.countryCodes {
                facts.append(fact(override.day, code, .manual))
            }
        }
        let annotations = plan.clearDays.map {
            DayAnnotationInput(day: $0, isCleared: true, hasNote: false)
        }
        return (facts, annotations)
    }

    /// Single-day pre-edit verdicts, the same way LedgerStore.day(_:) sees
    /// them (no neighbors, so gap-fill contributes nothing).
    private func preEditCodes(
        facts: [CountryFactInput],
        gapFill: GapFillPolicy = .fillShortGaps(maxDays: 3)
    ) -> (Int) -> [String] {
        { day in
            DayLedgerResolver(homeCountry: nil, gapFill: gapFill)
                .resolve(facts: facts, annotations: [], range: day...day)
                .first?.countryCodes ?? []
        }
    }

    func testShrinkingAGpsBackedTripActuallyShrinksTheSegment() {
        // The reported bug: a 10-day trip built from automatic evidence,
        // shrunk to 7 days, must not re-derive as 10 days.
        let automatic = (1...10).map { fact($0, "FR", .gps) }
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...10,
            keeping: 1...7,
            resolvedCodes: preEditCodes(facts: automatic)
        )
        XCTAssertEqual(plan.clearDays, [8, 9, 10])

        let state = simulateReplace(
            automatic: automatic, newCountry: "FR", newRange: 1...7, plan: plan
        )
        let resolver = DayLedgerResolver(homeCountry: nil, gapFill: .fillShortGaps(maxDays: 3))
        let days = resolver.resolve(facts: state.facts, annotations: state.annotations, range: 1...12)
        let segments = DayLedgerResolver.segments(from: days).filter { $0.countryCode == "FR" }
        XCTAssertEqual(segments, [TripSegment(countryCode: "FR", startDay: 1, endDay: 7)])
    }

    func testShrinkingAManualTripFencesAssumeStayedCarryForward() {
        // Manual-only trip shrunk under "assume I stayed": without the
        // cleared days, gap-fill would re-extend FR through day 15.
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...10,
            keeping: 1...7,
            resolvedCodes: preEditCodes(facts: (1...10).map { fact($0, "FR", .manual) })
        )
        let state = simulateReplace(
            automatic: [], newCountry: "FR", newRange: 1...7, plan: plan
        )
        let resolver = DayLedgerResolver(homeCountry: nil, gapFill: .assumePreviousLocation)
        let days = resolver.resolve(facts: state.facts, annotations: state.annotations, range: 1...15)
        let segments = DayLedgerResolver.segments(from: days)
        XCTAssertEqual(segments, [TripSegment(countryCode: "FR", startDay: 1, endDay: 7)])
    }

    func testShrinkingPastABorderDayKeepsTheOtherCountry() {
        // Day 10 is an FR/ES border day and ES continues through day 15.
        // Shrinking FR to 1...8 must keep day 10 Spanish.
        let automatic = (1...10).map { fact($0, "FR", .gps) }
            + (10...15).map { fact($0, "ES", .gps) }
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...10,
            keeping: 1...8,
            resolvedCodes: preEditCodes(facts: automatic)
        )
        XCTAssertEqual(plan.clearDays, [9])
        XCTAssertEqual(plan.overrideDays, [.init(day: 10, countryCodes: ["ES"])])

        let state = simulateReplace(
            automatic: automatic, newCountry: "FR", newRange: 1...8, plan: plan
        )
        let resolver = DayLedgerResolver(homeCountry: nil, gapFill: .leaveEmpty)
        let days = resolver.resolve(facts: state.facts, annotations: state.annotations, range: 1...15)
        let segments = DayLedgerResolver.segments(from: days).sorted { $0.startDay < $1.startDay }
        XCTAssertEqual(segments, [
            TripSegment(countryCode: "FR", startDay: 1, endDay: 8),
            TripSegment(countryCode: "ES", startDay: 10, endDay: 15),
        ])
    }

    func testDeletingATripClearsItsGapFilledTail() {
        // Facts only cover days 1...7; assume-stayed extends the trip to 10
        // on screen. Deleting the 1...10 trip must clear the filled tail
        // too, so nothing carries beyond it.
        let automatic = (1...7).map { fact($0, "FR", .gps) }
        let plan = TripEditPlanner.plan(
            removingCountry: "FR",
            from: 1...10,
            keeping: nil,
            resolvedCodes: preEditCodes(facts: automatic)
        )
        XCTAssertEqual(plan.clearDays, Array(1...10))

        // deleteTrip purges the country's manual facts (none here) and
        // applies the plan; automatic facts stay but cleared days hide them.
        let annotations = plan.clearDays.map {
            DayAnnotationInput(day: $0, isCleared: true, hasNote: false)
        }
        let resolver = DayLedgerResolver(homeCountry: nil, gapFill: .assumePreviousLocation)
        let days = resolver.resolve(facts: automatic, annotations: annotations, range: 1...15)
        XCTAssertTrue(DayLedgerResolver.segments(from: days).isEmpty)
    }
}
