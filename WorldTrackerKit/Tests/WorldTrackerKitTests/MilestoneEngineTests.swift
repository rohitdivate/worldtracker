import XCTest
@testable import WorldTrackerKit

final class MilestoneEngineTests: XCTestCase {
    private func snapshot(
        countries: Int = 0, days: Int = 0, longest: Int = 0, start: Int? = nil
    ) -> MilestoneSnapshot {
        MilestoneSnapshot(
            distinctCountries: countries, lifetimeTravelDays: days,
            longestTripDays: longest, longestTripStartDay: start
        )
    }

    func testSingleCountryCrossing() {
        let crossed = MilestoneEngine.crossed(
            before: snapshot(countries: 4), after: snapshot(countries: 5)
        )
        XCTAssertEqual(crossed, [.countryCount(5)])
    }

    func testUnchangedSnapshotCrossesNothing() {
        let now = snapshot(countries: 25, days: 300, longest: 12, start: 100)
        XCTAssertEqual(MilestoneEngine.crossed(before: now, after: now), [])
    }

    /// 20 countries is exactly the 10%-of-195 boundary: 20×100=2000 ≥ 1950,
    /// while 19×100=1900 falls short.
    func testWorldPercentBoundaryAtTwentyCountries() {
        let crossed = MilestoneEngine.crossed(
            before: snapshot(countries: 19), after: snapshot(countries: 20)
        )
        XCTAssertEqual(crossed, [.countryCount(20), .worldPercent(10)])
        let notYet = MilestoneEngine.crossed(
            before: snapshot(countries: 18), after: snapshot(countries: 19)
        )
        XCTAssertFalse(notYet.contains(.worldPercent(10)))
    }

    /// A bulk jump (big import) reports every crossing, presentation-ordered:
    /// countries (largest first) > world% > travel days.
    func testBulkCrossingOrder() {
        let crossed = MilestoneEngine.crossed(
            before: snapshot(countries: 3, days: 20),
            after: snapshot(countries: 22, days: 260)
        )
        XCTAssertEqual(crossed, [
            .countryCount(20), .countryCount(15), .countryCount(10), .countryCount(5),
            .worldPercent(10),
            .travelDays(250), .travelDays(100), .travelDays(50),
        ])
    }

    /// The seed pass uses before == .zero: everything currently held reports,
    /// so the tracker can mark it all awarded silently.
    func testSeedFromZeroReportsEverythingHeld() {
        let crossed = MilestoneEngine.crossed(
            before: .zero, after: snapshot(countries: 12, days: 80)
        )
        XCTAssertTrue(crossed.contains(.countryCount(5)))
        XCTAssertTrue(crossed.contains(.countryCount(10)))
        XCTAssertTrue(crossed.contains(.travelDays(50)))
        XCTAssertFalse(crossed.contains(.countryCount(15)))
    }

    func testLongestTripBeatenNeedsARealPreviousBest() {
        // First trip ever: 0 → 6 days must NOT fire.
        let first = MilestoneEngine.crossed(
            before: snapshot(countries: 2, longest: 0),
            after: snapshot(countries: 2, longest: 6, start: 500)
        )
        XCTAssertTrue(first.isEmpty)
        // A genuine beat fires with the new stretch's identity.
        let beaten = MilestoneEngine.crossed(
            before: snapshot(countries: 2, longest: 6, start: 500),
            after: snapshot(countries: 2, longest: 9, start: 700)
        )
        XCTAssertEqual(beaten, [.longestTripBeaten(days: 9, startDay: 700)])
        // Equal length is not a beat.
        let tie = MilestoneEngine.crossed(
            before: snapshot(countries: 2, longest: 9, start: 500),
            after: snapshot(countries: 2, longest: 9, start: 700)
        )
        XCTAssertTrue(tie.isEmpty)
    }

    func testStorageKeysAreStableAndDistinct() {
        let keys = [
            Milestone.countryCount(10).storageKey,
            Milestone.travelDays(10).storageKey,
            Milestone.worldPercent(10).storageKey,
            Milestone.longestTripBeaten(days: 10, startDay: 10).storageKey,
        ]
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(Milestone.countryCount(10).storageKey, "milestone-countries-10")
    }
}
