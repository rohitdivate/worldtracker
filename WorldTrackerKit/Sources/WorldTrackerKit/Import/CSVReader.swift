import Foundation

/// Minimal RFC-4180 CSV reader: quoted fields, escaped quotes ("" inside
/// quotes), embedded commas/newlines in quoted fields, CRLF/LF endings,
/// UTF-8 BOM stripping. Flighty exports carry free-text Notes columns, so a
/// naive split-on-comma is not an option.
public struct CSVReader {
    public static func rows(from data: Data) -> [[String]] {
        var bytes = [UInt8](data)
        // Strip UTF-8 BOM.
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            bytes.removeFirst(3)
        }

        var rows: [[String]] = []
        var row: [String] = []
        var field = [UInt8]()
        var inQuotes = false
        var index = 0

        func endField() {
            field.removeAll(keepingCapacity: true)
        }
        func pushField() {
            row.append(String(decoding: field, as: UTF8.self))
            endField()
        }
        func pushRow() {
            pushField()
            // Skip rows that are entirely empty (trailing newline artifacts).
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while index < bytes.count {
            let byte = bytes[index]
            if inQuotes {
                if byte == UInt8(ascii: "\"") {
                    if index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "\"") {
                        field.append(UInt8(ascii: "\""))
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(byte)
                }
            } else {
                switch byte {
                case UInt8(ascii: "\""):
                    inQuotes = true
                case UInt8(ascii: ","):
                    pushField()
                case UInt8(ascii: "\r"):
                    if index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "\n") {
                        index += 1
                    }
                    pushRow()
                case UInt8(ascii: "\n"):
                    pushRow()
                default:
                    field.append(byte)
                }
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            pushRow()
        }
        return rows
    }
}
