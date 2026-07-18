import Foundation

public struct CityHit: Sendable, Equatable {
    public let name: String
    public let admin1: String
    public let countryCode: String
    public let timeZoneID: String
    public let population: Int
    public let distanceMeters: Double
}

/// Nearest-city lookup over the bundled GeoNames data (cities.bin, WTC2).
/// 1-degree cell grid with spiral search, plus the "promotion rule": a suburb
/// yields to a >=10x-larger city within 15 km, so the answer is the city a
/// human would name.
public final class CityIndex: @unchecked Sendable {
    private let r: BinaryReader
    private let cityCount: Int
    private let poolSize: Int
    private let tzCount: Int
    private let ccCount: Int

    private let cityOff: Int
    private let firstOff: Int
    private let poolOff: Int
    private let tzOff: Int
    private let ccOff: Int

    private static let stride = 24
    private static let cells = 360 * 180

    public enum CityIndexError: Error {
        case badMagic
    }

    public init(data: Data) throws {
        let r = BinaryReader(data: data)
        guard r.ascii(0, count: 4) == "WTC2" else { throw CityIndexError.badMagic }
        cityCount = Int(r.u32(4))
        poolSize = Int(r.u32(8))
        tzCount = Int(r.u16(12))
        ccCount = Int(r.u16(14))
        cityOff = 16
        firstOff = cityOff + cityCount * Self.stride
        poolOff = firstOff + (Self.cells + 1) * 4
        tzOff = poolOff + poolSize
        ccOff = tzOff + tzCount * 4
        self.r = r
    }

    public convenience init(url: URL) throws {
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    public func nearestCity(to point: GeoPoint, maxKm: Double) -> CityHit? {
        guard let (index, distance) = nearestIndex(to: point, maxKm: maxKm) else {
            return nil
        }
        let promoted = promote(from: index, at: point) ?? (index, distance)
        return hit(promoted.0, distance: promoted.1)
    }

    // MARK: - Internals

    private func cityLat(_ i: Int) -> Double { Double(r.f32(cityOff + i * Self.stride)) }
    private func cityLon(_ i: Int) -> Double { Double(r.f32(cityOff + i * Self.stride + 4)) }
    private func cityPop(_ i: Int) -> Int { Int(r.u32(cityOff + i * Self.stride + 20)) }

    private func first(_ cell: Int) -> Int { Int(r.u32(firstOff + cell * 4)) }

    private func hit(_ i: Int, distance: Double) -> CityHit {
        let base = cityOff + i * Self.stride
        let nameOff = Int(r.u32(base + 8))
        let admin1Off = Int(r.u32(base + 12))
        let ccIdx = Int(r.u16(base + 16))
        let tzIdx = Int(r.u16(base + 18))
        let tzStrOff = Int(r.u32(tzOff + tzIdx * 4))
        return CityHit(
            name: r.pascalString(poolOff + nameOff),
            admin1: r.pascalString(poolOff + admin1Off),
            countryCode: r.ascii(ccOff + ccIdx * 2, count: 2),
            timeZoneID: r.pascalString(poolOff + tzStrOff),
            population: cityPop(i),
            distanceMeters: distance
        )
    }

    private func nearestIndex(to p: GeoPoint, maxKm: Double) -> (Int, Double)? {
        let y0 = min(179, max(0, Int(p.latitude + 90)))
        let x0 = min(359, max(0, Int(p.longitude + 180)))
        var best: (Int, Double)?
        var bestD = maxKm * 1000
        let maxRings = Int(maxKm / 111) + 2

        for ring in 0...maxRings {
            for dy in -ring...ring {
                for dx in -ring...ring {
                    guard max(abs(dx), abs(dy)) == ring else { continue }
                    let y = y0 + dy
                    guard y >= 0, y < 180 else { continue }
                    let x = ((x0 + dx) % 360 + 360) % 360
                    let cell = y * 360 + x
                    let lo = first(cell)
                    let hi = first(cell + 1)
                    for i in lo..<hi {
                        let d = Haversine.meters(
                            from: p,
                            to: GeoPoint(latitude: cityLat(i), longitude: cityLon(i))
                        )
                        if d < bestD {
                            bestD = d
                            best = (i, d)
                        }
                    }
                }
            }
            if let (_, d) = best, ring > Int(d / 111_000) + 1 {
                break
            }
        }
        return best
    }

    /// Suburb -> metropolis promotion (mirrors Tools/geodata/golden_check.py).
    private func promote(from nearest: Int, at p: GeoPoint) -> (Int, Double)? {
        let threshold = max(50_000, cityPop(nearest) * 10)
        let y0 = min(179, max(0, Int(p.latitude + 90)))
        let x0 = min(359, max(0, Int(p.longitude + 180)))
        var winner: (Int, Double)?
        var winnerPop = 0
        for dy in -1...1 {
            for dx in -1...1 {
                let y = y0 + dy
                guard y >= 0, y < 180 else { continue }
                let x = ((x0 + dx) % 360 + 360) % 360
                let cell = y * 360 + x
                for i in first(cell)..<first(cell + 1) {
                    let pop = cityPop(i)
                    guard pop >= threshold, pop > winnerPop else { continue }
                    let d = Haversine.meters(
                        from: p,
                        to: GeoPoint(latitude: cityLat(i), longitude: cityLon(i))
                    )
                    if d <= 15_000 {
                        winner = (i, d)
                        winnerPop = pop
                    }
                }
            }
        }
        return winner
    }
}
