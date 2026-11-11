import XCTest
@testable import WorldTrackerKit

final class InsightsTests: XCTestCase {
    private func epoch(_ year: Int, _ month: Int, _ day: Int) -> Int {
        EpochDay.daysFromCivil(year: year, month: month, day: day)
    }

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

    /// Round-number coordinates so distances are easy to reason about.
    private let points: [String: GeoPoint] = [
        "GB": GeoPoint(latitude: 51.5, longitude: 0),
        "FR": GeoPoint(latitude: 48.9, longitude: 2.3),
        "JP": GeoPoint(latitude: 35.7, longitude: 139.7),
        "AU": GeoPoint(latitude: -33.9, longitude: 151.2),
        "ES": GeoPoint(latitude: 40.4, longitude: -3.7),
    ]

    private func insights(
        _ days: [ResolvedDay], home: String? = "GB", today: Int? = nil
    ) -> TravelInsights {
        TravelInsightsEngine.compute(
            days: days,
            homeTimeline: .single(home),
            today: today ?? days.last?.day ?? 0,
            coordinate: { self.points[$0] }
        )
    }

    // MARK: - Continents

    func testSovereignTableIsTheHundredAndNinetyFive() {
        XCTAssertEqual(ContinentTable.sovereign.count, 195)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .africa), 54)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .asia), 48)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .europe), 44)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .northAmerica), 23)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .southAmerica), 12)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .oceania), 14)
        XCTAssertEqual(ContinentTable.sovereignCount(in: .antarctica), 0)
    }

    /// A code listed under two continents would be silently overwritten in
    /// the lookup; the per-continent lists must partition the table.
    func testNoCodeSitsOnTwoContinents() {
        let perContinent = Continent.allCases.reduce(0) {
            $0 + ContinentTable.sovereignCount(in: $1)
        }
        XCTAssertEqual(perContinent, ContinentTable.sovereign.count)
        for code in ContinentTable.allCodes {
            XCTAssertEqual(code.count, 2, "\(code) is not an alpha-2 code")
        }
    }

    func testContinentLookup() {
        XCTAssertEqual(ContinentTable.continent(of: "JP"), .asia)
        XCTAssertEqual(ContinentTable.continent(of: "gb"), .europe)
        XCTAssertEqual(ContinentTable.continent(of: "TR"), .asia)
        XCTAssertEqual(ContinentTable.continent(of: "RU"), .europe)
        XCTAssertEqual(ContinentTable.continent(of: "HK"), .asia)
        XCTAssertEqual(ContinentTable.continent(of: "AQ"), .antarctica)
        XCTAssertNil(ContinentTable.continent(of: "ZZ"))
    }

    /// Every country the offline atlas can return must have a continent, or
    /// a real visit silently drops out of the rings.
    func testEveryAtlasCountryHasAContinent() throws {
        let shapes = try WorldMapShapes()
        let geocoder = try GeoLookup().countries
        let detailed = (0..<geocoder.numberOfCountries).map(geocoder.code(forCountryIndex:))
        let missing = Set(shapes.countryCodes + detailed)
            .filter { ContinentTable.continent(of: $0) == nil }
            .sorted()
        XCTAssertEqual(missing, [], "atlas codes without a continent")
    }

    func testContinentProgressCountsTerritoriesAndCapsTheRing() {
        let progress = ContinentProgress.compute(visited: ["GB", "FR", "JP", "HK", "AQ", "ZZ"])
        let byContinent = Dictionary(uniqueKeysWithValues: progress.map { ($0.continent, $0) })
        XCTAssertEqual(progress.map(\.continent), Continent.allCases)
        XCTAssertEqual(byContinent[.europe]?.visited, 2)
        XCTAssertEqual(byContinent[.asia]?.visited, 2)
        XCTAssertEqual(byContinent[.africa]?.visited, 0)
        XCTAssertEqual(byContinent[.europe]?.fraction ?? 0, 2.0 / 44.0, accuracy: 1e-9)
        // No sovereign states to measure against: any visit fills the ring.
        XCTAssertEqual(byContinent[.antarctica]?.fraction, 1)
        XCTAssertEqual(byContinent[.southAmerica]?.fraction, 0)
    }

    // MARK: - Passport

    func testStampsTrackFirstLastTotalAndVisits() {
        let days = ledger(0...40, [
            (0...40, ["GB"]),
            (5...9, ["FR"]),
            (20...22, ["FR"]),
            (30...30, ["GB", "ES"]),
        ])
        let stamps = PassportBook.stamps(from: days)
        let fr = stamps.first { $0.code == "FR" }
        XCTAssertEqual(fr?.firstDay, 5)
        XCTAssertEqual(fr?.lastDay, 22)
        XCTAssertEqual(fr?.totalDays, 8)
        XCTAssertEqual(fr?.visits, 2)
        XCTAssertEqual(fr?.continent, .europe)

        // Home is interrupted by the two French stays: three separate runs,
        // and the border day still counts as a day there.
        let gb = stamps.first { $0.code == "GB" }
        XCTAssertEqual(gb?.visits, 3)
        XCTAssertEqual(gb?.totalDays, 41 - 5 - 3)

        // Newest first-visit leads.
        XCTAssertEqual(stamps.map(\.code), ["ES", "FR", "GB"])
    }

    func testUnknownDayBetweenSightingsStartsANewVisit() {
        let days = ledger(0...4, [(0...1, ["IT"]), (3...4, ["IT"])])
        XCTAssertEqual(PassportBook.stamps(from: days).first?.visits, 2)
    }

    func testWishlistPutsUnvisitedFirstAndDropsDuplicates() {
        let stamps = PassportBook.stamps(from: ledger(0...20, [(0...3, ["JP"]), (10...12, ["PE"])]))
        let entries = Wishlist.entries(codes: ["PE", "NZ", "JP", "NZ", "AR"], stamps: stamps)
        XCTAssertEqual(entries.map(\.code), ["AR", "NZ", "PE", "JP"])
        XCTAssertEqual(entries.map(\.isVisited), [false, false, true, true])
        XCTAssertEqual(entries.last?.visitedOn, 0)
    }

    // MARK: - Insights

    func testDistanceFollowsTheChainOfCountries() {
        // Home, a border day out, three days in France, a border day back.
        let days = ledger(0...10, [
            (0...10, ["GB"]),
            (3...3, ["FR", "GB"]),
            (4...6, ["FR"]),
            (7...7, ["GB", "FR"]),
        ])
        let result = insights(days)
        let leg = Haversine.meters(from: points["GB"]!, to: points["FR"]!) / 1000
        XCTAssertEqual(result.legs, 2)
        XCTAssertEqual(Double(result.totalKm), leg * 2, accuracy: 1.0)
        XCTAssertEqual(result.countries, 2)
    }

    func testLegsWithoutACoordinateAreSkipped() {
        let days = ledger(0...9, [(0...2, ["GB"]), (3...5, ["XX"]), (6...9, ["FR"])])
        let result = insights(days)
        XCTAssertEqual(result.legs, 0)
        XCTAssertEqual(result.totalKm, 0)
    }

    func testFarthestPointIsMeasuredFromHome() {
        let days = ledger(0...30, [
            (0...30, ["GB"]), (5...8, ["FR"]), (12...18, ["JP"]), (22...25, ["AU"]),
        ])
        let result = insights(days)
        XCTAssertEqual(result.farthest?.code, "AU")
        XCTAssertGreaterThan(result.farthest?.km ?? 0, 16_000)
        XCTAssertTrue(result.crossedEquator)
    }

    func testNorthernOnlyTravelHasNotCrossedTheEquator() {
        let result = insights(ledger(0...9, [(0...9, ["GB"]), (3...5, ["JP"])]))
        XCTAssertFalse(result.crossedEquator)
    }

    func testAwayAndHomeStretches() {
        let days = ledger(0...40, [
            (0...40, ["GB"]),
            (5...9, ["FR"]),            // 5 days away
            (20...31, ["ES"]),          // 12 days away
            (32...33, ["FR"]),          // …continues into France: 14 total
        ])
        let result = insights(days)
        XCTAssertEqual(result.longestAway?.dayCount, 14)
        XCTAssertEqual(result.longestAway?.countryCodes, ["ES", "FR"])
        XCTAssertEqual(result.travelDays, 19)
        XCTAssertEqual(result.trackedDays, 41)
        XCTAssertEqual(result.longestHomeStretch, 10)   // days 10…19
        XCTAssertEqual(result.averageTripDays ?? 0, 9.5, accuracy: 1e-9)
        XCTAssertEqual(result.awayShare, 19.0 / 41.0, accuracy: 1e-9)
    }

    /// Nothing is known about an unrecorded day, so it ends a run instead of
    /// being bridged.
    func testUnknownDayBreaksAStretch() {
        let days = ledger(0...10, [(0...3, ["FR"]), (5...10, ["FR"])])
        let result = insights(days)
        XCTAssertEqual(result.longestAway?.dayCount, 6)
        XCTAssertEqual(result.trackedDays, 10)
    }

    func testMostCountriesInAWeek() {
        let days = ledger(0...20, [
            (0...20, ["GB"]),
            (10...11, ["FR"]), (12...13, ["BE"]), (14...15, ["NL"]),
        ])
        // Days 9…15 hold GB, FR, BE and NL.
        XCTAssertEqual(insights(days).mostCountriesInAWeek, 4)
    }

    func testByYearCountsNewCountriesOnce() {
        let y1 = epoch(2024, 1, 1)
        let y2 = epoch(2025, 1, 1)
        let end = epoch(2025, 12, 31)
        let days = ledger(y1...end, [
            (y1...end, ["GB"]),
            ((y1 + 30)...(y1 + 35), ["FR"]),
            ((y2 + 30)...(y2 + 35), ["FR"]),
            ((y2 + 60)...(y2 + 70), ["JP"]),
        ])
        let result = insights(days, today: end)
        XCTAssertEqual(result.byYear.map(\.year), [2024, 2025])
        XCTAssertEqual(result.byYear[0].countries, 2)
        XCTAssertEqual(result.byYear[0].newCountries, 2)
        XCTAssertEqual(result.byYear[0].travelDays, 6)
        XCTAssertEqual(result.byYear[1].countries, 3)
        XCTAssertEqual(result.byYear[1].newCountries, 1)
        XCTAssertEqual(result.byYear[1].travelDays, 17)
        XCTAssertEqual(result.bestYearCountries, 3)
        // March 2025 holds the eleven Japan days; February has ten in all.
        XCTAssertEqual(result.favouriteMonth, 3)
    }

    func testPaceComparesTheSameStretchOfLastYear() {
        let start = epoch(2025, 1, 1)
        let today = epoch(2026, 3, 1)
        let days = ledger(start...today, [
            (start...today, ["GB"]),
            (epoch(2025, 2, 1)...epoch(2025, 2, 10), ["FR"]),     // inside the stretch
            (epoch(2025, 6, 1)...epoch(2025, 6, 20), ["JP"]),     // after it
            (epoch(2026, 1, 5)...epoch(2026, 1, 8), ["ES"]),
        ])
        let pace = insights(days, today: today).pace
        XCTAssertEqual(pace?.dayOfYear, 60)
        XCTAssertEqual(pace?.countriesThisYear, 2)
        XCTAssertEqual(pace?.countriesLastYear, 2)
        XCTAssertEqual(pace?.travelDaysThisYear, 4)
        XCTAssertEqual(pace?.travelDaysLastYear, 10)
    }

    func testPaceNeedsLastYearsData() {
        let today = epoch(2026, 3, 1)
        let days = ledger(epoch(2026, 1, 1)...today, [(epoch(2026, 1, 1)...today, ["GB"])])
        XCTAssertNil(insights(days, today: today).pace)
    }

    func testEmptyLedger() {
        let result = insights([])
        XCTAssertEqual(result.countries, 0)
        XCTAssertEqual(result.totalKm, 0)
        XCTAssertNil(result.farthest)
        XCTAssertNil(result.longestAway)
        XCTAssertEqual(result.awayShare, 0)
    }

    func testCityExtremes() {
        func city(_ name: String, _ lat: Double, _ lon: Double) -> CityDays {
            CityDays(key: name, name: name, countryCode: nil, days: 1, latitude: lat, longitude: lon)
        }
        let extremes = CityExtremes.compute([
            city("Oslo", 59.9, 10.8), city("Sydney", -33.9, 151.2),
            city("San Francisco", 37.8, -122.4), city("Tokyo", 35.7, 139.7),
        ])
        XCTAssertEqual(extremes.northernmost?.name, "Oslo")
        XCTAssertEqual(extremes.southernmost?.name, "Sydney")
        XCTAssertEqual(extremes.easternmost?.name, "Sydney")
        XCTAssertEqual(extremes.westernmost?.name, "San Francisco")
        XCTAssertNil(CityExtremes.compute([]).northernmost)
    }

    // MARK: - Achievements

    func testBadgesUnlockAtTheirTargets() {
        let badges = AchievementEngine.evaluate(.init(
            countries: 10, continents: 3, travelDays: 99, longestTripDays: 14,
            totalKm: 12_000, schengenCountries: 4, crossedEquator: true,
            mostCountriesInAWeek: 2, bestYearCountries: 9, wishlistVisited: 0
        ))
        let byID = Dictionary(uniqueKeysWithValues: badges.map { ($0.id, $0) })
        XCTAssertEqual(byID["countries-10"]?.isUnlocked, true)
        XCTAssertEqual(byID["countries-25"]?.isUnlocked, false)
        XCTAssertEqual(byID["countries-25"]?.fraction ?? 0, 0.4, accuracy: 1e-9)
        XCTAssertEqual(byID["continents-3"]?.isUnlocked, true)
        XCTAssertEqual(byID["days-100"]?.isUnlocked, false)
        XCTAssertEqual(byID["trip-14"]?.isUnlocked, true)
        XCTAssertEqual(byID["equator"]?.isUnlocked, true)
        XCTAssertEqual(byID["km-world"]?.isUnlocked, false)
        XCTAssertEqual(byID["week-3"]?.isUnlocked, false)
        XCTAssertEqual(badges.count, Set(badges.map(\.id)).count, "badge ids must be unique")
    }

    func testProgressNeverOverflowsTheTarget() {
        let badges = AchievementEngine.evaluate(.init(countries: 80, totalKm: 900_000))
        for badge in badges {
            XCTAssertLessThanOrEqual(badge.current, badge.target)
            XCTAssertLessThanOrEqual(badge.fraction, 1)
        }
    }

    func testAchievementInputIsBuiltFromInsightsAndStamps() {
        let days = ledger(0...40, [
            (0...40, ["GB"]), (5...9, ["FR"]), (12...18, ["JP"]), (22...25, ["AU"]),
        ])
        let stamps = PassportBook.stamps(from: days)
        let input = AchievementEngine.input(
            insights: insights(days), stamps: stamps, wishlistVisited: 1
        )
        XCTAssertEqual(input.countries, 4)
        XCTAssertEqual(input.continents, 3)
        XCTAssertEqual(input.schengenCountries, 1)
        XCTAssertEqual(input.longestTripDays, 7)
        XCTAssertTrue(input.crossedEquator)
        XCTAssertEqual(input.wishlistVisited, 1)
    }

    // MARK: - Year grid

    func testYearGridAlignsWeeksOnMonday() {
        // 1 January 2026 is a Thursday.
        let grid = YearGrid(year: 2026)
        XCTAssertEqual(grid.cells.count, 365)
        XCTAssertEqual(grid.cells[0].row, 3)
        XCTAssertEqual(grid.cells[0].column, 0)
        XCTAssertEqual(grid.cells[3].row, 6)        // Sunday the 4th
        XCTAssertEqual(grid.cells[4].row, 0)        // Monday the 5th…
        XCTAssertEqual(grid.cells[4].column, 1)     // …starts the next column
        XCTAssertEqual(grid.columns, 53)
        XCTAssertEqual(grid.months.count, 12)
        XCTAssertEqual(grid.months[0].column, 0)
        XCTAssertEqual(grid.cells[0].epochDay, epoch(2026, 1, 1))
        // Columns only ever move forward through the year.
        XCTAssertEqual(grid.months.map(\.column), grid.months.map(\.column).sorted())
    }

    func testYearGridLeapYear() {
        XCTAssertEqual(YearGrid(year: 2024).cells.count, 366)
    }

    func testWeekdayIndex() {
        XCTAssertEqual(YearGrid.weekdayIndex(0), 3)                    // Thu 1 Jan 1970
        XCTAssertEqual(YearGrid.weekdayIndex(epoch(2026, 11, 9)), 0)   // a Monday
        XCTAssertEqual(YearGrid.weekdayIndex(-1), 2)                   // Wed 31 Dec 1969
    }

    func testDayTone() {
        func day(_ codes: [String]) -> ResolvedDay {
            ResolvedDay(day: 0, countryCodes: codes, source: nil, isFilled: false)
        }
        XCTAssertEqual(DayTone.tone(for: day([]), home: "GB"), .unknown)
        XCTAssertEqual(DayTone.tone(for: day(["GB"]), home: "GB"), .home)
        XCTAssertEqual(DayTone.tone(for: day(["FR"]), home: "GB"), .away)
        XCTAssertEqual(DayTone.tone(for: day(["GB", "FR"]), home: "GB"), .crossing)
        XCTAssertEqual(DayTone.tone(for: day(["FR"]), home: nil), .away)
    }
}
