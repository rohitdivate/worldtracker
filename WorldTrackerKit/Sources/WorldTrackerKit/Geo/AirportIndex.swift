import Foundation

public struct Airport: Sendable, Equatable {
    public let iata: String
    public let point: GeoPoint
    public let countryCode: String
}

/// IATA → airport lookup over the bundled airports.bin (WTA1, ~9k records,
/// sorted by IATA for binary search).
public final class AirportIndex: @unchecked Sendable {
    private let r: BinaryReader
    private let count: Int
    private static let headerSize = 8
    private static let stride = 13

    public enum AirportIndexError: Error {
        case badMagic
    }

    public init(data: Data) throws {
        let r = BinaryReader(data: data)
        guard r.ascii(0, count: 4) == "WTA1" else { throw AirportIndexError.badMagic }
        count = Int(r.u32(4))
        self.r = r
    }

    public convenience init(bundle: Bundle) throws {
        var url = bundle.url(forResource: "airports", withExtension: "bin", subdirectory: "GeoData")
        if url == nil, let base = bundle.resourceURL {
            let candidate = base.appendingPathComponent("GeoData/airports.bin")
            if FileManager.default.fileExists(atPath: candidate.path) {
                url = candidate
            }
        }
        guard let url else { throw AirportIndexError.badMagic }
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    public convenience init() throws {
        try self.init(bundle: Bundle.module)
    }

    public var numberOfAirports: Int { count }

    public func airport(iata code: String) -> Airport? {
        let target = code.uppercased()
        guard target.count == 3 else { return nil }

        var low = 0
        var high = count - 1
        while low <= high {
            let mid = (low + high) / 2
            let offset = Self.headerSize + mid * Self.stride
            let midCode = r.ascii(offset, count: 3)
            if midCode == target {
                return Airport(
                    iata: midCode,
                    point: GeoPoint(
                        latitude: Double(r.f32(offset + 3)),
                        longitude: Double(r.f32(offset + 7))
                    ),
                    countryCode: r.ascii(offset + 11, count: 2)
                )
            } else if midCode < target {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return nil
    }
}
