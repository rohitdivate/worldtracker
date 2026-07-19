import XCTest
@testable import WorldTrackerKit

final class DayLedgerResolverTests: XCTestCase {
    private func fact(
        _ day: Int, _ code: String, _ source: FactSource,
        confidence: Double = 1.0, evidence: Int = 1
    ) -> CountryFactInput {
        CountryFactInput(day: day, countryCode: code, source: source, confidence: confidence, evidenceCount: evidence)
    }

    private let plain = DayLedgerResolver(homeCountry: "GB", gapFill: .leaveEmpty)

    func testPrecedenceManualBeatsEverything() {
        let days = plain.resolve(
            facts: [
                fact(10, "FR", .gps, evidence: 50),
                fact(10, "ES", .photo, evidence: 50),
                fact(10, "IT", .manual),
            ],
            annotations: [],
            range: 10...10
        )
        XCTAssertEqual(days[0].countryCodes, ["IT"])
        XCTAssertEqual(days[0].source, .manual)
    }

    func testPrecedenceGpsBeatsPhotoBeatsHint() {
        let days = plain.resolve(
            facts: [
                fact(1, "FR", .timezoneHint),
                fact(1, "ES", .photo),
                fact(2, "DE", .timezoneHint),
                fact(2, "PT", .photo, evidence: 3),
                fact(3, "NL", .timezoneHint),
            ],
            annotations: [],
            range: 1...3
        )
        XCTAssertEqual(days[0].countryCodes, ["ES"])
        XCTAssertEqual(days[0].source, .photo)
        XCTAssertEqual(days[1].countryCodes, ["PT"])
        XCTAssertEqual(days[2].countryCodes, ["NL"])
        XCTAssertEqual(days[2].source, .timezoneHint)
    }

    func testBorderDayHasBothCountriesOrderedByEvidence() {
        let days = plain.resolve(
            facts: [
                fact(5, "GB", .gps, evidence: 2),
                fact(5, "ES", .gps, evidence: 6),
            ],
            annotations: [],
            range: 5...5
        )
        XCTAssertEqual(days[0].countryCodes, ["ES", "GB"])
    }

    func testClearedDayIsEmptyAndBlocksGapFill() {
        let resolver = DayLedgerResolver(homeCountry: "GB", gapFill: .assumePreviousLocation)
        let days = resolver.resolve(
            facts: [
                fact(1, "GB", .gps),
                fact(6, "FR", .gps),
            ],
            annotations: [DayAnnotationInput(day: 3, isCleared: true, hasNote: false)],
            range: 1...6
        )
        // Day 2 fills from GB; day 3 cleared; days 4-5 must NOT fill
        // (the cleared day broke the chain).
        XCTAssertEqual(days[1].countryCodes, ["GB"])
        XCTAssertTrue(days[1].isFilled)
        XCTAssertEqual(days[2].countryCodes, [])
        XCTAssertEqual(days[3].countryCodes, [])
        XCTAssertEqual(days[4].countryCodes, [])
        XCTAssertEqual(days[5].countryCodes, ["FR"])
    }

    func testFillShortGapsRespectsMaxLength() {
        let resolver = DayLedgerResolver(homeCountry: nil, gapFill: .fillShortGaps(maxDays: 3))
        let days = resolver.resolve(
            facts: [
                fact(1, "GB", .gps),
                fact(5, "GB", .gps),   // gap of 3 (days 2,3,4) — fills
                fact(15, "GB", .gps),  // gap of 9 (days 6..14) — stays empty
            ],
            annotations: [],
            range: 1...15
        )
        XCTAssertEqual(days[1].countryCodes, ["GB"])
        XCTAssertTrue(days[1].isFilled)
        XCTAssertEqual(days[3].countryCodes, ["GB"])
        XCTAssertEqual(days[5].countryCodes, [])
        XCTAssertEqual(days[10].countryCodes, [])
    }

    func testAssumePreviousFillsTrailingGap() {
        let resolver = DayLedgerResolver(homeCountry: nil, gapFill: .assumePreviousLocation)
        let days = resolver.resolve(
            facts: [fact(1, "ES", .gps)],
            annotations: [],
            range: 1...4
        )
        XCTAssertEqual(days[3].countryCodes, ["ES"])
        XCTAssertTrue(days[3].isFilled)
    }

    func testSegmentsOverlapOnBorderDays() {
        // GB GB GB|ES ES ES|GB GB
        let facts = [
            fact(1, "GB", .gps), fact(2, "GB", .gps),
            fact(3, "GB", .gps), fact(3, "ES", .gps),
            fact(4, "ES", .gps), fact(5, "ES", .gps), fact(5, "GB", .gps),
            fact(6, "GB", .gps),
        ]
        let days = plain.resolve(facts: facts, annotations: [], range: 1...6)
        let segments = DayLedgerResolver.segments(from: days)

        let gb = segments.filter { $0.countryCode == "GB" }
        let es = segments.filter { $0.countryCode == "ES" }
        XCTAssertEqual(es.count, 1)
        XCTAssertEqual(es[0].startDay, 3)
        XCTAssertEqual(es[0].endDay, 5)
        XCTAssertEqual(es[0].dayCount, 3)
        // GB: 1-3 and 5-6 (border days 3 and 5 belong to both).
        XCTAssertEqual(gb.count, 2)
        XCTAssertEqual(Set(gb.map { "\($0.startDay)-\($0.endDay)" }), ["1-3", "5-6"])
    }

    func testStatsAnyPresenceAndCrossings() {
        let facts = [
            fact(1, "GB", .gps),
            fact(2, "GB", .gps), fact(2, "ES", .gps, evidence: 2),  // border day
            fact(3, "ES", .gps),
            fact(4, "ES", .gps), fact(4, "GB", .gps, evidence: 2),  // border day back
            fact(5, "GB", .gps),
        ]
        let days = plain.resolve(facts: facts, annotations: [], range: 1...5)
        let stats = DayLedgerResolver.stats(for: days, home: "GB")

        XCTAssertEqual(stats.daysPerCountry["GB"], 4)  // days 1,2,4,5
        XCTAssertEqual(stats.daysPerCountry["ES"], 3)  // days 2,3,4
        XCTAssertEqual(stats.countriesVisited, 2)
        XCTAssertEqual(stats.travelDays, 3)            // days 2,3,4 not exactly [GB]
        XCTAssertEqual(stats.borderCrossings, 2)
    }

    func testEmptyRangeAndNoFacts() {
        let days = plain.resolve(facts: [], annotations: [], range: 1...3)
        XCTAssertEqual(days.count, 3)
        XCTAssertTrue(days.allSatisfy { $0.countryCodes.isEmpty && !$0.isFilled })
        let stats = DayLedgerResolver.stats(for: days, home: "GB")
        XCTAssertEqual(stats.countriesVisited, 0)
        XCTAssertEqual(stats.travelDays, 0)
    }

    func testImportedBeatsPhotoLosesToGpsAndManual() {
        let days = plain.resolve(
            facts: [
                fact(1, "FR", .photo, evidence: 40),
                fact(1, "ES", .importedTimeline),
                fact(2, "DE", .importedTimeline, evidence: 40),
                fact(2, "PT", .gps),
                fact(3, "IT", .importedFlight, evidence: 40),
                fact(3, "NL", .manual),
            ],
            annotations: [],
            range: 1...3
        )
        XCTAssertEqual(days[0].countryCodes, ["ES"])
        XCTAssertEqual(days[0].source, .importedTimeline)
        XCTAssertEqual(days[1].countryCodes, ["PT"])
        XCTAssertEqual(days[1].source, .gps)
        XCTAssertEqual(days[2].countryCodes, ["NL"])
        XCTAssertEqual(days[2].source, .manual)
    }

    func testTimelineAndFlightMergeAsBorderDay() {
        let days = plain.resolve(
            facts: [
                fact(5, "GB", .importedFlight),
                fact(5, "ES", .importedTimeline, evidence: 3),
            ],
            annotations: [],
            range: 5...5
        )
        XCTAssertEqual(Set(days[0].countryCodes), Set(["GB", "ES"]))
        XCTAssertEqual(days[0].countryCodes.first, "ES") // higher evidence first
        XCTAssertEqual(days[0].source, .importedTimeline) // deterministic display
    }

    func testNotePropagates() {
        let days = plain.resolve(
            facts: [fact(1, "GB", .gps)],
            annotations: [DayAnnotationInput(day: 1, isCleared: false, hasNote: true)],
            range: 1...1
        )
        XCTAssertTrue(days[0].hasNote)
    }
}
