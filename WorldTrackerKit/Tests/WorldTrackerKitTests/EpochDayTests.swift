import XCTest
@testable import WorldTrackerKit

final class EpochDayTests: XCTestCase {
    func testEpochZero() {
        XCTAssertEqual(EpochDay.daysFromCivil(year: 1970, month: 1, day: 1), 0)
        XCTAssertEqual(EpochDay(value: 0).civil().year, 1970)
        XCTAssertEqual(EpochDay(value: 0).civil().month, 1)
        XCTAssertEqual(EpochDay(value: 0).civil().day, 1)
    }

    func testCivilRoundTrip() {
        for value in [-1_000, -1, 0, 1, 10_000, 20_000, 20_541] {
            let day = EpochDay(value: value)
            let (y, m, d) = day.civil()
            XCTAssertEqual(EpochDay.daysFromCivil(year: y, month: m, day: d), value)
        }
    }

    func testKnownDates() {
        // 2026-03-29 (the user's Barcelona trip day).
        let day = EpochDay.daysFromCivil(year: 2026, month: 3, day: 29)
        XCTAssertEqual(EpochDay(value: day).civil().month, 3)
        XCTAssertEqual(EpochDay(value: day).civil().day, 29)
        // Leap day.
        let leap = EpochDay.daysFromCivil(year: 2024, month: 2, day: 29)
        let c = EpochDay(value: leap).civil()
        XCTAssertEqual(c.month, 2)
        XCTAssertEqual(c.day, 29)
    }

    func testPlaceTimezoneBucketing() throws {
        // 2026-03-29 22:30 UTC is still March 29 in London,
        // but already March 30 in Tokyo. The photo belongs to the place.
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 29
        comps.hour = 22
        comps.minute = 30
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let instant = try XCTUnwrap(utcCal.date(from: comps))

        let london = EpochDay(date: instant, timeZone: TimeZone(identifier: "Europe/London")!)
        let tokyo = EpochDay(date: instant, timeZone: TimeZone(identifier: "Asia/Tokyo")!)

        XCTAssertEqual(london.civil().day, 29)
        XCTAssertEqual(tokyo.civil().day, 30)
        XCTAssertEqual(tokyo.value - london.value, 1)
    }

    func testStartDate() {
        let day = EpochDay(value: EpochDay.daysFromCivil(year: 2026, month: 7, day: 18))
        let utc = TimeZone(identifier: "UTC")!
        let start = day.startDate(in: utc)
        let back = EpochDay(date: start, timeZone: utc)
        XCTAssertEqual(back, day)
    }

    func testHaversine() {
        let london = GeoPoint(latitude: 51.5074, longitude: -0.1278)
        let paris = GeoPoint(latitude: 48.8566, longitude: 2.3522)
        let d = Haversine.meters(from: london, to: paris)
        XCTAssertEqual(d, 343_500, accuracy: 5_000) // ~343.5 km
    }
}
