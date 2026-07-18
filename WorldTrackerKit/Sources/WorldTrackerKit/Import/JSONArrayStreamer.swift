import Foundation

/// Streams the elements of one named JSON array from a file WITHOUT loading
/// the document into memory. Google Takeout Records.json can exceed a
/// gigabyte; this reads fixed-size chunks and tracks brace depth with full
/// string/escape awareness, handing each complete array element's bytes to a
/// callback for normal JSONDecoder use.
///
/// Memory: O(chunkSize + largest single element).
/// Supports arrays of objects (all Google formats qualify).
public struct JSONArrayStreamer {
    public enum StreamError: Error, Equatable {
        case keyNotFound(String)
        case malformed(String)
    }

    private let chunkSize: Int

    public init(chunkSize: Int = 4 << 20) {
        self.chunkSize = max(64, chunkSize)
    }

    /// Find `"key": [ ... ]` and invoke `element` once per `{...}` element.
    /// `progress` receives bytesRead/fileSize in [0, 1].
    public func streamArray(
        at url: URL,
        key: String,
        element: (Data) throws -> Void,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = (try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

        let quote = UInt8(ascii: "\"")
        let backslash = UInt8(ascii: "\\")
        let openBrace = UInt8(ascii: "{")
        let closeBrace = UInt8(ascii: "}")
        let openBracket = UInt8(ascii: "[")
        let closeBracket = UInt8(ascii: "]")

        let keyPattern = Array("\"\(key)\"".utf8)

        var phase = Phase.seekingKey
        var keyMatch = 0
        var inString = false
        var escaped = false
        var depth = 0
        var buffer = Data()
        var bytesRead = 0
        var foundArray = false

        func consumeStringByte(_ byte: UInt8) {
            if escaped {
                escaped = false
            } else if byte == backslash {
                escaped = true
            } else if byte == quote {
                inString = false
            }
        }

        while true {
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                break
            }
            bytesRead += chunk.count
            if fileSize > 0 {
                progress?(min(1, Double(bytesRead) / Double(fileSize)))
            }

            for byte in chunk {
                switch phase {
                case .seekingKey:
                    if inString {
                        // Inside some other string value; check if that string
                        // was exactly the key by tracking the match below.
                        consumeStringByte(byte)
                        continue
                    }
                    if byte == keyPattern[keyMatch] {
                        keyMatch += 1
                        if keyMatch == keyPattern.count {
                            phase = .seekingColon
                            keyMatch = 0
                        }
                    } else {
                        keyMatch = (byte == keyPattern[0]) ? 1 : 0
                        if byte == quote, keyMatch == 0 {
                            inString = true
                        }
                    }

                case .seekingColon:
                    if byte == UInt8(ascii: ":") {
                        phase = .seekingBracket
                    } else if isWhitespace(byte) {
                        continue
                    } else {
                        phase = .seekingKey
                    }

                case .seekingBracket:
                    if byte == openBracket {
                        phase = .betweenElements
                        foundArray = true
                    } else if isWhitespace(byte) {
                        continue
                    } else {
                        phase = .seekingKey
                    }

                case .betweenElements:
                    if byte == closeBracket {
                        return
                    }
                    if byte == openBrace {
                        depth = 1
                        buffer.removeAll(keepingCapacity: true)
                        buffer.append(byte)
                        phase = .inElement
                    }
                    // commas / whitespace between elements: skip

                case .inElement:
                    buffer.append(byte)
                    if inString {
                        consumeStringByte(byte)
                        continue
                    }
                    if byte == quote {
                        inString = true
                    } else if byte == openBrace || byte == openBracket {
                        depth += 1
                    } else if byte == closeBrace || byte == closeBracket {
                        depth -= 1
                        if depth == 0 {
                            try element(buffer)
                            phase = .betweenElements
                        }
                    }
                }
            }
        }

        if !foundArray {
            throw StreamError.keyNotFound(key)
        }
        if phase == .inElement {
            throw StreamError.malformed("unterminated element in array \"\(key)\"")
        }
        // Ending inside .betweenElements without the closing bracket means a
        // truncated file — tolerate it: all complete elements were delivered.
    }

    private func isWhitespace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\n")
            || byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\t")
    }

    private enum Phase {
        case seekingKey
        case seekingColon
        case seekingBracket
        case betweenElements
        case inElement
    }
}
