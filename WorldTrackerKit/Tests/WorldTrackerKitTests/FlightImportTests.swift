import XCTest
@testable import WorldTrackerKit

final class FlightImportTests: XCTestCase {
    static var airports: AirportIndex!
    static var lookup: GeoLookup!

    override class func setUp() {
        super.setUp()
        airports = try! AirportIndex()
        lookup = try! GeoLookup()
    }

    private func fixture(_ name: String, _ ext: String) throws -> Data {
        var url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
        if url == nil, let base = Bundle.module.resourceURL {
            let candidate = base.appendingPathComponent("Fixtures/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                url = candidate
            }
        }
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testAirportIndexLookups() {
        XCTAssertGreaterThan(Self.airports.numberOfAirports, 7_000)
        let lhr = Self.airports.airport(iata: "LHR")
        XCTAssertEqual(lhr?.countryCode, "GB")
        XCTAssertEqual(lhr?.point.latitude ?? 0, 51.47, accuracy: 0.2)
        XCTAssertEqual(Self.airports.airport(iata: "jfk")?.countryCode, "US")
        XCTAssertEqual(Self.airports.airport(iata: "HND")?.countryCode, "JP")
        XCTAssertNil(Self.airports.airport(iata: "ZZZ"))
        XCTAssertNil(Self.airports.airport(iata: "TOOLONG"))
    }

    func testFlightyParsing() throws {
        let data = try fixture("flighty_sample", "csv")
        let (flights, skipped) = try FlightCSVParser.parse(data: data)

        // 5 data rows: 1 canceled (skipped) → 4 flights.
        XCTAssertEqual(flights.count, 4)
        XCTAssertEqual(skipped, 1)

        let outbound = flights[0]
        XCTAssertEqual(outbound.originIATA, "LHR")
        XCTAssertEqual(outbound.destinationIATA, "BCN")
        XCTAssertEqual(EpochDay(value: outbound.departureDay).civil().day, 29)
        XCTAssertNotNil(outbound.departure)  // actual preferred
        XCTAssertNotNil(outbound.arrival)

        // Diverted flight lands at the diversion airport.
        let diverted = flights[3]
        XCTAssertEqual(diverted.originIATA, "MAD")
        XCTAssertEqual(diverted.destinationIATA, "BOD")
    }

    func testGenericParsing() throws {
        let data = try fixture("generic_flights", "csv")
        let (flights, skipped) = try FlightCSVParser.parse(data: data)
        XCTAssertEqual(flights.count, 4)
        XCTAssertEqual(skipped, 1)  // the bad row (header excluded)
        XCTAssertEqual(flights[2].originIATA, "STN")
        XCTAssertEqual(flights[2].destinationIATA, "RAK")
    }

    func testUnrecognizedFormatThrows() {
        let junk = "colA;colB\n1;2\n".data(using: .utf8)!
        XCTAssertThrowsError(try FlightCSVParser.parse(data: junk))
    }

    func testFlightDayFactsOvernightArrival() throws {
        let data = try fixture("flighty_sample", "csv")
        let (flights, _) = try FlightCSVParser.parse(data: data)
        let (facts, unknown, used) = flightDayFacts(
            flights: flights, airports: Self.airports, lookup: Self.lookup
        )

        XCTAssertEqual(used, 4)
        XCTAssertTrue(unknown.isEmpty)

        // LHR→HND departs Nov 14, arrives Nov 15 in Asia/Tokyo.
        let nov14 = EpochDay.daysFromCivil(year: 2026, month: 11, day: 14)
        let nov15 = EpochDay.daysFromCivil(year: 2026, month: 11, day: 15)
        XCTAssertTrue(facts.contains { $0.day == nov14 && $0.countryCode == "GB" })
        XCTAssertTrue(facts.contains { $0.day == nov15 && $0.countryCode == "JP" })
        XCTAssertFalse(facts.contains { $0.day == nov14 && $0.countryCode == "JP" })

        // Diverted MAD→BOD credits France, not the original ORY destination day pairing.
        let jun20 = EpochDay.daysFromCivil(year: 2026, month: 6, day: 20)
        XCTAssertTrue(facts.contains { $0.day == jun20 && $0.countryCode == "ES" })
        XCTAssertTrue(facts.contains { $0.day == jun20 && $0.countryCode == "FR" })
    }

    func testUnknownIATASurfaces() {
        let flights = [
            FlightRecord(departureDay: 20_000, originIATA: "QQQ", destinationIATA: "LHR", departure: nil, arrival: nil)
        ]
        let (facts, unknown, used) = flightDayFacts(
            flights: flights, airports: Self.airports, lookup: Self.lookup
        )
        XCTAssertTrue(facts.isEmpty)
        XCTAssertEqual(unknown, ["QQQ"])
        XCTAssertEqual(used, 0)
    }
}
