import XCTest
@testable import WorldTrackerKit

/// Runs the same golden fixtures as Tools/geodata/golden_check.py against the
/// Swift readers, so Python reference and Swift implementation are proven to
/// agree on the exact committed binaries.
final class GeoLookupTests: XCTestCase {
    struct Fixture: Decodable {
        let name: String
        let lat: Double
        let lon: Double
        let country: String?
        let cityContains: String?
        let tz: String?
    }

    static var lookup: GeoLookup!
    static var fixtures: [Fixture] = []

    override class func setUp() {
        super.setUp()
        lookup = try! GeoLookup()
        var url = Bundle.module.url(
            forResource: "golden_lookups", withExtension: "json", subdirectory: "Fixtures"
        )
        if url == nil, let base = Bundle.module.resourceURL {
            let candidate = base.appendingPathComponent("Fixtures/golden_lookups.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                url = candidate
            }
        }
        fixtures = try! JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url!))
    }

    func testGoldenFixtures() {
        XCTAssertFalse(Self.fixtures.isEmpty)
        for fx in Self.fixtures {
            let res = Self.lookup.resolve(GeoPoint(latitude: fx.lat, longitude: fx.lon))

            switch fx.country {
            case nil:
                XCTAssertNil(res.countryCode, "\(fx.name): expected no country, got \(res.countryCode ?? "-")")
            case "*":
                XCTAssertNotNil(res.countryCode, "\(fx.name): expected some country")
            case let want? where want.hasPrefix("~"):
                let allowed = want.dropFirst().split(separator: "|").map(String.init)
                XCTAssertTrue(
                    res.countryCode.map(allowed.contains) ?? false,
                    "\(fx.name): country \(res.countryCode ?? "nil") not in \(allowed)"
                )
                XCTAssertTrue(res.usedNearestLandFallback || res.countryCode != nil, fx.name)
            case let want? where want.contains("|"):
                let allowed = want.split(separator: "|").map(String.init)
                XCTAssertTrue(
                    res.countryCode.map(allowed.contains) ?? false,
                    "\(fx.name): country \(res.countryCode ?? "nil") not in \(allowed)"
                )
            case let want?:
                XCTAssertEqual(res.countryCode, want, fx.name)
            }

            if let contains = fx.cityContains, !contains.isEmpty {
                XCTAssertTrue(
                    (res.cityName ?? "").localizedCaseInsensitiveContains(contains),
                    "\(fx.name): city \(res.cityName ?? "nil") should contain \(contains)"
                )
            }
            if let tz = fx.tz, !tz.isEmpty {
                XCTAssertEqual(res.timeZoneID, tz, fx.name)
            }
        }
    }

    func testTimezoneHint() {
        XCTAssertEqual(Self.lookup.countryCode(forTimeZoneID: "Europe/London"), "GB")
        XCTAssertEqual(Self.lookup.countryCode(forTimeZoneID: "Europe/Paris"), "FR")
        XCTAssertNil(Self.lookup.countryCode(forTimeZoneID: "Not/AZone"))
    }

    func testFlagEmoji() {
        XCTAssertEqual(flagEmoji("GB"), "🇬🇧")
        XCTAssertEqual(flagEmoji("fr"), "🇫🇷")
    }

    func testLookupPerformance() {
        // Photo backfill does tens of thousands of these; keep it fast.
        let points = (0..<2_000).map { i -> GeoPoint in
            GeoPoint(
                latitude: 35 + Double(i % 40) * 0.5,
                longitude: -10 + Double(i % 80) * 0.5
            )
        }
        measure {
            for p in points {
                _ = Self.lookup.resolve(p)
            }
        }
    }
}
