import XCTest
@testable import WorldTrackerKit

final class PhotoClustererTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(_ id: String, _ lat: Double, _ lon: Double, minutes: Double) -> PhotoSample {
        PhotoSample(
            id: id,
            point: GeoPoint(latitude: lat, longitude: lon),
            timestamp: base.addingTimeInterval(minutes * 60)
        )
    }

    func testSingleTightClusterSurvives() {
        let samples = [
            sample("a", 51.5100, -0.1300, minutes: 0),
            sample("b", 51.5101, -0.1301, minutes: 10),
            sample("c", 51.5102, -0.1299, minutes: 20),
            sample("d", 51.5100, -0.1298, minutes: 25),
        ]
        let clusters = clusterPhotoSamples(samples)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].assetIDs.count, 4)
        XCTAssertEqual(clusters[0].center.latitude, 51.5101, accuracy: 0.0005)
    }

    func testOutlierPhotoIsDropped() {
        // Two real visits and one lone mistagged photo far away.
        let samples = [
            sample("a", 51.51, -0.13, minutes: 0),
            sample("b", 51.51, -0.13, minutes: 5),
            sample("c", 51.51, -0.13, minutes: 10),
            sample("x", 48.85, 2.35, minutes: 12),   // lone Paris outlier
            sample("d", 51.52, -0.14, minutes: 200),
            sample("e", 51.52, -0.14, minutes: 210),
            sample("f", 51.52, -0.14, minutes: 220),
        ]
        let clusters = clusterPhotoSamples(samples)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertFalse(clusters.flatMap(\.assetIDs).contains("x"))
    }

    func testTimeGapSplitsClusters() {
        let samples = [
            sample("a", 51.51, -0.13, minutes: 0),
            sample("b", 51.51, -0.13, minutes: 10),
            sample("c", 51.51, -0.13, minutes: 20),
            // Same spot, but 5 hours later — separate visit.
            sample("d", 51.51, -0.13, minutes: 320),
            sample("e", 51.51, -0.13, minutes: 330),
            sample("f", 51.51, -0.13, minutes: 340),
        ]
        let clusters = clusterPhotoSamples(samples)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].assetIDs, ["a", "b", "c"])
        XCTAssertEqual(clusters[1].assetIDs, ["d", "e", "f"])
    }

    func testMinCountConfigurable() {
        let samples = [
            sample("a", 51.51, -0.13, minutes: 0),
            sample("b", 51.51, -0.13, minutes: 5),
        ]
        XCTAssertTrue(clusterPhotoSamples(samples).isEmpty)
        let loose = clusterPhotoSamples(samples, config: ClusterConfig(minCount: 2))
        XCTAssertEqual(loose.count, 1)
    }

    func testEmptyInput() {
        XCTAssertTrue(clusterPhotoSamples([]).isEmpty)
    }
}
