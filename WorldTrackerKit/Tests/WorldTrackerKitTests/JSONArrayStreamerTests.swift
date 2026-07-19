import XCTest
@testable import WorldTrackerKit

final class JSONArrayStreamerTests: XCTestCase {
    private func write(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("streamer-\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func collect(_ json: String, key: String, chunkSize: Int = 64) throws -> [[String: Any]] {
        let url = try write(json)
        var out: [[String: Any]] = []
        try JSONArrayStreamer(chunkSize: chunkSize).streamArray(at: url, key: key) { data in
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                out.append(obj)
            }
        }
        return out
    }

    func testBasicArray() throws {
        let elements = try collect(
            #"{"locations": [{"a": 1}, {"a": 2}, {"a": 3}], "other": 5}"#,
            key: "locations"
        )
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements[2]["a"] as? Int, 3)
    }

    func testElementSplitAcrossChunkBoundaries() throws {
        // Tiny chunks force every element to straddle reads.
        let big = (0..<200).map { #"{"index": \#($0), "text": "value \#($0)"}"# }
            .joined(separator: ",\n")
        let elements = try collect(#"{"records": [\#(big)]}"#, key: "records", chunkSize: 64)
        XCTAssertEqual(elements.count, 200)
        XCTAssertEqual(elements[199]["index"] as? Int, 199)
    }

    func testStringsContainingBracesAndEscapes() throws {
        let json = #"{"items": [{"s": "a } ] \" , { [ b"}, {"s": "plain"}]}"#
        let elements = try collect(json, key: "items")
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0]["s"] as? String, #"a } ] " , { [ b"#)
    }

    func testNestedObjectsAndArrays() throws {
        let json = #"{"segs": [{"visit": {"loc": {"latLng": "1,2"}}, "path": [1, 2, [3]]}]}"#
        let elements = try collect(json, key: "segs")
        XCTAssertEqual(elements.count, 1)
        XCTAssertNotNil(elements[0]["visit"])
    }

    func testKeyAppearingInsideStringValueIsIgnored() throws {
        let json = #"{"note": "the word \"locations\" appears here", "locations": [{"a": 1}]}"#
        let elements = try collect(json, key: "locations")
        XCTAssertEqual(elements.count, 1)
    }

    func testMissingKeyThrows() throws {
        let url = try write(#"{"foo": [1]}"#)
        XCTAssertThrowsError(
            try JSONArrayStreamer(chunkSize: 64).streamArray(at: url, key: "locations") { _ in }
        ) { error in
            XCTAssertEqual(
                error as? JSONArrayStreamer.StreamError,
                .keyNotFound("locations")
            )
        }
    }

    func testEmptyArray() throws {
        let elements = try collect(#"{"locations": []}"#, key: "locations")
        XCTAssertTrue(elements.isEmpty)
    }

    func testStopsAtArrayEndIgnoringRest() throws {
        let json = #"{"a": [{"x": 1}], "b": [{"x": 99}]}"#
        let elements = try collect(json, key: "a")
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0]["x"] as? Int, 1)
    }
}
