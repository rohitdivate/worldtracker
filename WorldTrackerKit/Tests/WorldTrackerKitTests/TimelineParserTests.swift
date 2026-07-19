import XCTest
@testable import WorldTrackerKit

final class TimelineParserTests: XCTestCase {
    private func fixtureURL(_ name: String) throws -> URL {
        var url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        if url == nil, let base = Bundle.module.resourceURL {
            let candidate = base.appendingPathComponent("Fixtures/\(name).json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                url = candidate
            }
        }
        return try XCTUnwrap(url)
    }

    private func parseAll(
        _ name: String, format: TimelineFormat, minInterval: TimeInterval = 0
    ) throws -> (samples: [TimelineSample], stays: [TimelineStay], summary: TimelineParseSummary) {
        var samples: [TimelineSample] = []
        var stays: [TimelineStay] = []
        let summary = try TimelineParser.parse(
            url: try fixtureURL(name),
            format: format,
            minSampleInterval: minInterval,
            onSample: { samples.append($0) },
            onStay: { stays.append($0) }
        )
        return (samples, stays, summary)
    }

    // MARK: - Detection

    func testFormatDetection() throws {
        XCTAssertEqual(TimelineParser.detectFormat(url: try fixtureURL("timeline_ondevice")), .onDeviceExport)
        XCTAssertEqual(TimelineParser.detectFormat(url: try fixtureURL("timeline_records")), .records)
        XCTAssertEqual(TimelineParser.detectFormat(url: try fixtureURL("timeline_semantic_month")), .semanticMonthly)
        XCTAssertNil(TimelineParser.detectFormat(head: Data("{\"foo\": []}".utf8)))
    }

    // MARK: - On-device export

    func testOnDeviceExport() throws {
        let (samples, stays, summary) = try parseAll("timeline_ondevice", format: .onDeviceExport)

        XCTAssertEqual(stays.count, 1)                    // the London visit
        XCTAssertEqual(stays[0].point.latitude, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(stays[0].utcOffsetSeconds, 0)

        // 2 timelinePath points + 2 activity endpoints.
        XCTAssertEqual(samples.count, 4)
        XCTAssertEqual(samples[0].point.longitude, 2.1686, accuracy: 0.0001)
        XCTAssertEqual(samples[0].utcOffsetSeconds, 3600)  // +01:00
        // Path offset: second point is 30 minutes after startTime.
        XCTAssertEqual(samples[1].timestamp.timeIntervalSince(samples[0].timestamp), 1800, accuracy: 1)

        XCTAssertEqual(summary.recordsRead, 4)
        XCTAssertEqual(summary.recordsSkipped, 1)          // the unknown segment kind
    }

    // MARK: - Records.json

    func testRecordsParsingWithCorruptionAndDownsampling() throws {
        let (samples, stays, summary) = try parseAll(
            "timeline_records", format: .records, minInterval: 600
        )
        XCTAssertTrue(stays.isEmpty)
        XCTAssertEqual(summary.recordsRead, 6)
        // Skipped: the 0,0 row and the row with no coordinates.
        XCTAssertEqual(summary.recordsSkipped, 2)
        // Downsampled: second London point 5 min after the first is dropped.
        XCTAssertEqual(samples.count, 3)

        // timestampMs path (Tokyo).
        XCTAssertEqual(samples[1].point.latitude, 35.6762, accuracy: 0.0001)
        // E7-corruption fix recovers Paris.
        XCTAssertEqual(samples[2].point.latitude, 48.8575, accuracy: 0.001)
        XCTAssertEqual(samples[2].point.longitude, 2.3514, accuracy: 0.001)
    }

    // MARK: - Semantic monthly

    func testSemanticMonthly() throws {
        let (samples, stays, summary) = try parseAll("timeline_semantic_month", format: .semanticMonthly)
        XCTAssertEqual(stays.count, 1)
        XCTAssertEqual(stays[0].point.latitude, 55.6761, accuracy: 0.0001)
        XCTAssertEqual(samples.count, 2)                  // activity start + end
        XCTAssertEqual(summary.recordsSkipped, 1)         // unknown object kind
    }

    // MARK: - Helpers

    func testLatLngStringParsing() {
        XCTAssertEqual(
            TimelineParser.latLngPoint(in: "48.8575°, 2.3514°"),
            GeoPoint(latitude: 48.8575, longitude: 2.3514)
        )
        XCTAssertEqual(
            TimelineParser.latLngPoint(in: ["latLng": "-33.86°,151.20°"]),
            GeoPoint(latitude: -33.86, longitude: 151.20)
        )
        XCTAssertNil(TimelineParser.latLngPoint(in: "not a coordinate"))
        XCTAssertNil(TimelineParser.latLngPoint(in: "999°, 2°"))
    }

    func testISOOffsetExtraction() {
        XCTAssertEqual(TimelineParser.parseISO("2026-03-29T15:00:00.000+01:00")?.offsetSeconds, 3600)
        XCTAssertEqual(TimelineParser.parseISO("2026-03-29T15:00:00Z")?.offsetSeconds, 0)
        XCTAssertEqual(TimelineParser.parseISO("2026-03-29T15:00:00.000-08:00")?.offsetSeconds, -28_800)
        XCTAssertNil(TimelineParser.parseISO("garbage"))
    }
}

final class TimelineDayAggregatorTests: XCTestCase {
    static var lookup: GeoLookup!

    override class func setUp() {
        super.setUp()
        lookup = try! GeoLookup()
    }

    func testTokyoEveningBucketsIntoNextLocalDay() {
        var aggregator = TimelineDayAggregator(lookup: Self.lookup)
        // 2026-03-29T22:30Z in Tokyo is already March 30 locally.
        let instant = Date(timeIntervalSince1970: 1_774_823_400)
        aggregator.add(TimelineSample(
            point: GeoPoint(latitude: 35.6762, longitude: 139.6503),
            timestamp: instant
        ))
        let (facts, countries, skipped) = aggregator.finish()
        XCTAssertEqual(skipped, 0)
        XCTAssertEqual(countries, ["JP"])
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(EpochDay(value: facts[0].day).civil().day, 30)
    }

    func testStaySpansEveryCoveredDay() {
        var aggregator = TimelineDayAggregator(lookup: Self.lookup)
        let start = TimelineParser.parseISO("2025-12-21T14:00:00Z")!.date
        let end = TimelineParser.parseISO("2025-12-23T10:00:00Z")!.date
        aggregator.add(TimelineStay(
            point: GeoPoint(latitude: 55.6761, longitude: 12.5683),
            start: start,
            end: end
        ))
        let (facts, countries, _) = aggregator.finish()
        XCTAssertEqual(countries, ["DK"])
        XCTAssertEqual(facts.count, 3)  // Dec 21, 22, 23
        XCTAssertTrue(facts.allSatisfy { $0.countryCode == "DK" })
    }

    func testOceanPointDropped() {
        var aggregator = TimelineDayAggregator(lookup: Self.lookup)
        aggregator.add(TimelineSample(
            point: GeoPoint(latitude: 30, longitude: -40),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        let (facts, countries, skipped) = aggregator.finish()
        XCTAssertTrue(facts.isEmpty)
        XCTAssertTrue(countries.isEmpty)
        XCTAssertEqual(skipped, 1)
    }

    func testEvidenceAggregatesPerDayCountry() {
        var aggregator = TimelineDayAggregator(lookup: Self.lookup)
        let base = TimelineParser.parseISO("2026-01-10T09:00:00Z")!.date
        for offset in 0..<5 {
            aggregator.add(TimelineSample(
                point: GeoPoint(latitude: 51.5074, longitude: -0.1278),
                timestamp: base.addingTimeInterval(Double(offset) * 3600)
            ))
        }
        let (facts, _, _) = aggregator.finish()
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts[0].evidenceCount, 5)
        XCTAssertEqual(facts[0].countryCode, "GB")
    }
}
