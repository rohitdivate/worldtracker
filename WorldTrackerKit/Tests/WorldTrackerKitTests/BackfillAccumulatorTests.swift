import XCTest
@testable import WorldTrackerKit

final class BackfillAccumulatorTests: XCTestCase {
    // Deterministic pseudo-random photo stream: 400 photos over ~40 days
    // across 3 countries/timezones with clustered coordinates.
    private struct Photo {
        let id: String
        let lat: Double
        let lon: Double
        let time: Date
        let country: String
        let city: String?
        let tz: String
    }

    private func syntheticPhotos() -> [Photo] {
        let zones = [
            ("JP", "Tokyo", "Asia/Tokyo", 35.68, 139.76),
            ("US", "Los Angeles", "America/Los_Angeles", 34.05, -118.24),
            ("FR", "Paris", "Europe/Paris", 48.85, 2.35),
        ]
        var photos: [Photo] = []
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max)
        }
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<400 {
            let zone = zones[i % zones.count]
            let jitterDays = Double(Int(next() * 40))
            let jitterSecs = next() * 80_000
            photos.append(Photo(
                id: "asset-\(i)",
                lat: zone.3 + (next() - 0.5) * 0.3,
                lon: zone.4 + (next() - 0.5) * 0.3,
                time: base.addingTimeInterval(jitterDays * 86_400 + jitterSecs),
                country: zone.0,
                city: zone.1,
                tz: zone.2
            ))
        }
        return photos.sorted { $0.time < $1.time }
    }

    private func feed(_ photo: Photo, into acc: inout BackfillAccumulator) {
        acc.add(
            assetID: photo.id, latitude: photo.lat, longitude: photo.lon,
            timestamp: photo.time, countryCode: photo.country,
            city: photo.city, timeZoneID: photo.tz
        )
    }

    /// Chunked flushes merged with the upsert rule must equal one unflushed run.
    func testChunkedEqualsOneShot() {
        let photos = syntheticPhotos()

        var oneShot = BackfillAccumulator()
        for photo in photos { feed(photo, into: &oneShot) }
        let (fullFacts, fullCells) = oneShot.flush()
        let expectedFacts = Dictionary(uniqueKeysWithValues: fullFacts.map { ("\($0.epochDay)|\($0.countryCode)", $0) })
        let expectedCells = Dictionary(uniqueKeysWithValues: fullCells.map { ("\($0.epochDay)|\($0.cellLatitude)|\($0.cellLongitude)", $0) })

        for chunkSize in [1, 7, 100, 5000] {
            var acc = BackfillAccumulator()
            var mergedFacts: [String: BackfillDayFact] = [:]
            var mergedCells: [String: BackfillCellEvidence] = [:]
            var index = 0
            while index < photos.count {
                let end = min(index + chunkSize, photos.count)
                for i in index..<end { feed(photos[i], into: &acc) }
                let (facts, cells) = acc.flush()
                for fact in facts {
                    let key = "\(fact.epochDay)|\(fact.countryCode)"
                    if var existing = mergedFacts[key] {
                        BackfillAccumulator.merge(into: &existing, fact)
                        mergedFacts[key] = existing
                    } else {
                        mergedFacts[key] = fact
                    }
                }
                for cell in cells {
                    let key = "\(cell.epochDay)|\(cell.cellLatitude)|\(cell.cellLongitude)"
                    if var existing = mergedCells[key] {
                        BackfillAccumulator.merge(into: &existing, cell)
                        mergedCells[key] = existing
                    } else {
                        mergedCells[key] = cell
                    }
                }
                index = end
            }
            XCTAssertEqual(mergedFacts, expectedFacts, "facts diverged at chunkSize \(chunkSize)")
            // Representative asset may differ across chunk boundaries (first of
            // its chunk vs first overall); compare everything except that.
            XCTAssertEqual(mergedCells.count, expectedCells.count, "cell count diverged at chunkSize \(chunkSize)")
            for (key, merged) in mergedCells {
                let expected = try! XCTUnwrap(expectedCells[key])
                XCTAssertEqual(merged.photoCount, expected.photoCount, "cell \(key) count at chunkSize \(chunkSize)")
                XCTAssertEqual(merged.countryCode, expected.countryCode)
            }
            XCTAssertEqual(acc.countriesInOrder.sorted(), oneShot.countriesInOrder.sorted())
            XCTAssertEqual(acc.uniqueDays, oneShot.uniqueDays)
        }
    }

    /// The same instant is a different calendar day in Tokyo vs Los Angeles.
    func testTimezoneDayBucketing() {
        // 2023-11-14T22:00:00Z → Nov 15 in Tokyo (+9), Nov 14 in LA (-8).
        let instant = Date(timeIntervalSince1970: 1_700_000_400)
        var acc = BackfillAccumulator()
        acc.add(assetID: "a", latitude: 35.68, longitude: 139.76, timestamp: instant,
                countryCode: "JP", city: nil, timeZoneID: "Asia/Tokyo")
        acc.add(assetID: "b", latitude: 34.05, longitude: -118.24, timestamp: instant,
                countryCode: "US", city: nil, timeZoneID: "America/Los_Angeles")
        let (facts, _) = acc.flush()
        XCTAssertEqual(facts.count, 2)
        let japan = facts.first { $0.countryCode == "JP" }!
        let states = facts.first { $0.countryCode == "US" }!
        XCTAssertEqual(japan.epochDay - states.epochDay, 1)
    }

    /// An unknown timezone identifier falls back to UTC, never crashes.
    func testInvalidTimezoneFallsBackToUTC() {
        let instant = Date(timeIntervalSince1970: 1_700_000_400)
        var withBadTZ = BackfillAccumulator()
        withBadTZ.add(assetID: "a", latitude: 0.5, longitude: 0.5, timestamp: instant,
                      countryCode: "GH", city: nil, timeZoneID: "Not/AZone")
        var withNilTZ = BackfillAccumulator()
        withNilTZ.add(assetID: "a", latitude: 0.5, longitude: 0.5, timestamp: instant,
                      countryCode: "GH", city: nil, timeZoneID: nil)
        XCTAssertEqual(withBadTZ.flush().dayFacts.first?.epochDay,
                       withNilTZ.flush().dayFacts.first?.epochDay)
    }

    /// A chunk boundary never splits a run of equal timestamps.
    func testTieSafeChunkBoundary() {
        // Timestamps: 0,1,2,2,2,3 — target 3 would cut inside the run of 2s.
        let stamps = [0.0, 1, 2, 2, 2, 3].map { Date(timeIntervalSince1970: $0) }
        let end = BackfillChunker.chunkEnd(start: 0, target: 3, count: stamps.count) { stamps[$0] }
        XCTAssertEqual(end, 5, "chunk must extend past the tie run")
        let next = BackfillChunker.chunkEnd(start: end, target: 3, count: stamps.count) { stamps[$0] }
        XCTAssertEqual(next, stamps.count)
    }

    func testChunkEndPlainBoundaries() {
        let stamps = (0..<10).map { Date(timeIntervalSince1970: Double($0)) }
        XCTAssertEqual(BackfillChunker.chunkEnd(start: 0, target: 4, count: 10) { stamps[$0] }, 4)
        XCTAssertEqual(BackfillChunker.chunkEnd(start: 4, target: 4, count: 10) { stamps[$0] }, 8)
        XCTAssertEqual(BackfillChunker.chunkEnd(start: 8, target: 4, count: 10) { stamps[$0] }, 10)
        // A whole array of one timestamp becomes a single chunk.
        let flat = Array(repeating: Date(timeIntervalSince1970: 7), count: 9)
        XCTAssertEqual(BackfillChunker.chunkEnd(start: 0, target: 2, count: 9) { flat[$0] }, 9)
    }

    /// Photos within the same 2-decimal cell on the same day merge into one
    /// evidence row; the representative asset is the first seen.
    func testCellDedupe() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var acc = BackfillAccumulator()
        acc.add(assetID: "first", latitude: 48.8511, longitude: 2.3499, timestamp: base,
                countryCode: "FR", city: "Paris", timeZoneID: "Europe/Paris")
        acc.add(assetID: "second", latitude: 48.8492, longitude: 2.3501, timestamp: base.addingTimeInterval(60),
                countryCode: "FR", city: "Paris", timeZoneID: "Europe/Paris")
        acc.add(assetID: "far", latitude: 48.99, longitude: 2.35, timestamp: base.addingTimeInterval(120),
                countryCode: "FR", city: nil, timeZoneID: "Europe/Paris")
        let (facts, cells) = acc.flush()
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts.first?.photoCount, 3)
        XCTAssertEqual(cells.count, 2)
        let merged = cells.first { $0.photoCount == 2 }!
        XCTAssertEqual(merged.representativeAssetID, "first")
        XCTAssertEqual(merged.cellLatitude, 48.85)
        XCTAssertEqual(merged.cellLongitude, 2.35)
    }

    /// The geocode cache key collapses ~110m neighborhoods and separates cells.
    func testGeoCacheKey() {
        let a = BackfillAccumulator.geoCacheKey(latitude: 48.8501, longitude: 2.3501)
        let b = BackfillAccumulator.geoCacheKey(latitude: 48.8504, longitude: 2.3504)
        let c = BackfillAccumulator.geoCacheKey(latitude: 48.8601, longitude: 2.3501)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// `add` reports a country only the first time it appears.
    func testNewCountrySignal() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var acc = BackfillAccumulator()
        XCTAssertTrue(acc.add(assetID: "a", latitude: 1, longitude: 1, timestamp: base,
                              countryCode: "IT", city: nil, timeZoneID: "Europe/Rome"))
        XCTAssertFalse(acc.add(assetID: "b", latitude: 1, longitude: 1, timestamp: base,
                               countryCode: "IT", city: nil, timeZoneID: "Europe/Rome"))
        _ = acc.flush()
        // Flushing must not reset country memory.
        XCTAssertFalse(acc.add(assetID: "c", latitude: 1, longitude: 1, timestamp: base,
                               countryCode: "IT", city: nil, timeZoneID: "Europe/Rome"))
        XCTAssertEqual(acc.countriesInOrder, ["IT"])
    }
}
