import XCTest
@testable import WorldTrackerKit

final class WorldMapShapesTests: XCTestCase {
    func testLoadsAndContainsMajorCountries() throws {
        let shapes = try WorldMapShapes()
        XCTAssertGreaterThan(shapes.countryCodes.count, 150)
        for code in ["GB", "FR", "ES", "US", "JP", "AU"] {
            let rings = shapes.rings(forCountry: code)
            XCTAssertFalse(rings.isEmpty, "no rings for \(code)")
            XCTAssertTrue(rings.allSatisfy { $0.count >= 4 })
        }
    }

    func testCentroidIsInsideSaneBounds() throws {
        let shapes = try WorldMapShapes()
        let gb = try XCTUnwrap(shapes.centroid(forCountry: "GB"))
        XCTAssertEqual(gb.latitude, 54, accuracy: 4)
        XCTAssertEqual(gb.longitude, -2.5, accuracy: 4)
    }

    func testGreatCircleArc() {
        let london = GeoPoint(latitude: 51.5, longitude: -0.12)
        let tokyo = GeoPoint(latitude: 35.68, longitude: 139.69)
        let arc = greatCircleArc(from: london, to: tokyo, samples: 16)
        XCTAssertEqual(arc.count, 17)
        XCTAssertEqual(arc.first!.latitude, london.latitude, accuracy: 0.01)
        XCTAssertEqual(arc.first!.longitude, london.longitude, accuracy: 0.01)
        XCTAssertEqual(arc.last!.latitude, tokyo.latitude, accuracy: 0.01)
        // Great circle to Tokyo goes far north of both endpoints.
        XCTAssertGreaterThan(arc.map(\.latitude).max()!, 60)
    }
}
