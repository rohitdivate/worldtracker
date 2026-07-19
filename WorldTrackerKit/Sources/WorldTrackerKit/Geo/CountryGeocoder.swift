import Foundation

/// Point-in-polygon country lookup over the bundled Natural Earth 1:50m data
/// (countries50m.bin, format WTC1). Fully offline; a lookup is a 1-degree grid
/// probe plus a bbox-prefiltered even-odd ray cast.
public final class CountryGeocoder: @unchecked Sendable {
    private let r: BinaryReader

    private let countryCount: Int
    private let polyCount: Int
    private let ringCount: Int
    private let pointCount: Int

    private let countriesOff: Int
    private let polysOff: Int
    private let ringsOff: Int
    private let pointsOff: Int
    private let gridOff: Int

    /// polygon index -> country index
    private let owner: [Int32]
    /// mixed grid cell -> candidate polygon indices
    private let mixed: [Int32: [UInt16]]

    private static let countryStride = 8
    private static let polyStride = 22
    private static let ringStride = 24

    public enum GeocoderError: Error {
        case badMagic
    }

    public init(data: Data) throws {
        let r = BinaryReader(data: data)
        guard r.ascii(0, count: 4) == "WTC1" else { throw GeocoderError.badMagic }
        countryCount = Int(r.u32(4))
        polyCount = Int(r.u32(8))
        ringCount = Int(r.u32(12))
        pointCount = Int(r.u32(16))

        countriesOff = 20
        polysOff = countriesOff + countryCount * Self.countryStride
        ringsOff = polysOff + polyCount * Self.polyStride
        pointsOff = ringsOff + ringCount * Self.ringStride
        gridOff = pointsOff + pointCount * 8

        var owner = [Int32](repeating: -1, count: polyCount)
        for ci in 0..<countryCount {
            let base = countriesOff + ci * Self.countryStride
            let first = Int(r.u32(base + 2))
            let count = Int(r.u16(base + 6))
            for pi in first..<(first + count) {
                owner[pi] = Int32(ci)
            }
        }
        self.owner = owner

        var mixed = [Int32: [UInt16]]()
        var off = gridOff + 360 * 180 * 2
        let mixedCount = Int(r.u32(off))
        off += 4
        for _ in 0..<mixedCount {
            let cell = Int32(r.u32(off))
            let n = Int(r.u16(off + 4))
            off += 6
            var cands = [UInt16]()
            cands.reserveCapacity(n)
            for i in 0..<n {
                cands.append(r.u16(off + i * 2))
            }
            off += n * 2
            mixed[cell] = cands
        }
        self.mixed = mixed
        self.r = r
    }

    public convenience init(url: URL) throws {
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    public func countryCode(at point: GeoPoint) -> String? {
        let lon = point.longitude
        let lat = point.latitude
        let x = min(359, max(0, Int(lon + 180)))
        let y = min(179, max(0, Int(lat + 90)))
        let cell = y * 360 + x
        let v = r.i16(gridOff + cell * 2)
        if v == -1 { return nil }

        let candidates: [UInt16]
        if v >= 0 {
            candidates = [UInt16(v)]
        } else {
            candidates = mixed[Int32(cell)] ?? []
        }
        for pi in candidates {
            if contains(polygon: Int(pi), lon: lon, lat: lat) {
                let ci = Int(owner[Int(pi)])
                return r.ascii(countriesOff + ci * Self.countryStride, count: 2)
            }
        }
        return nil
    }

    /// ISO code for a country index (used by map rendering).
    public func code(forCountryIndex index: Int) -> String {
        r.ascii(countriesOff + index * Self.countryStride, count: 2)
    }

    public var numberOfCountries: Int { countryCount }

    private func contains(polygon pi: Int, lon: Double, lat: Double) -> Bool {
        let base = polysOff + pi * Self.polyStride
        let minLon = Double(r.f32(base + 6))
        let minLat = Double(r.f32(base + 10))
        let maxLon = Double(r.f32(base + 14))
        let maxLat = Double(r.f32(base + 18))
        guard lon >= minLon, lon <= maxLon, lat >= minLat, lat <= maxLat else {
            return false
        }
        let firstRing = Int(r.u32(base))
        let ringN = Int(r.u16(base + 4))
        var crossings = 0
        for ri in firstRing..<(firstRing + ringN) {
            if inRing(ri, lon: lon, lat: lat) {
                crossings += 1
            }
        }
        return crossings % 2 == 1
    }

    private func inRing(_ ri: Int, lon: Double, lat: Double) -> Bool {
        let base = ringsOff + ri * Self.ringStride
        let minLon = Double(r.f32(base + 8))
        let minLat = Double(r.f32(base + 12))
        let maxLon = Double(r.f32(base + 16))
        let maxLat = Double(r.f32(base + 20))
        guard lon >= minLon, lon <= maxLon, lat >= minLat, lat <= maxLat else {
            return false
        }
        let firstPoint = Int(r.u32(base))
        let n = Int(r.u32(base + 4))
        var inside = false
        var px = Double(r.f32(pointsOff + (firstPoint + n - 1) * 8))
        var py = Double(r.f32(pointsOff + (firstPoint + n - 1) * 8 + 4))
        for i in 0..<n {
            let off = pointsOff + (firstPoint + i) * 8
            let cx = Double(r.f32(off))
            let cy = Double(r.f32(off + 4))
            if (cy > lat) != (py > lat) {
                let xint = (px - cx) * (lat - cy) / (py - cy) + cx
                if lon < xint {
                    inside.toggle()
                }
            }
            px = cx
            py = cy
        }
        return inside
    }
}
