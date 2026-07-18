import XCTest
@testable import WorldTrackerKit

final class CSVReaderTests: XCTestCase {
    private func rows(_ csv: String) -> [[String]] {
        CSVReader.rows(from: csv.data(using: .utf8)!)
    }

    func testSimple() {
        let result = rows("a,b,c\n1,2,3\n")
        XCTAssertEqual(result, [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testQuotedFieldsWithCommasAndNewlines() {
        let result = rows("date,notes\n2026-01-01,\"Landed late, very tired\nlong day\"\n")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1][1], "Landed late, very tired\nlong day")
    }

    func testEscapedQuotes() {
        let result = rows(#"a,b"# + "\n" + #""say ""hi"" now",x"#)
        XCTAssertEqual(result[1][0], #"say "hi" now"#)
    }

    func testCRLFAndBOM() {
        let bom = "\u{FEFF}"
        let result = rows("\(bom)h1,h2\r\nv1,v2\r\n")
        XCTAssertEqual(result, [["h1", "h2"], ["v1", "v2"]])
    }

    func testTrailingNewlineAndEmptyLines() {
        let result = rows("a,b\n\n1,2\n\n")
        XCTAssertEqual(result, [["a", "b"], ["1", "2"]])
    }

    func testNoTrailingNewline() {
        let result = rows("a,b\n1,2")
        XCTAssertEqual(result, [["a", "b"], ["1", "2"]])
    }
}
