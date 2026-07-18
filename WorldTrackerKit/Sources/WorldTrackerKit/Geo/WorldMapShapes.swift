import Foundation

/// Reader for map110m.bin (WTM1) — lightweight country outlines for the
/// Map tab's polygon overlays.
public final class WorldMapShapes: @unchecked Sendable {
    private let r: BinaryReader
    private let countryCount: Int
    private let polyCount: Int
    private let ringCount: Int

    private let countriesOff: Int
    private let polysOff: Int
    private let ringsOff: Int
    private let pointsOff: Int

    /// code → (firstPoly, polyCount)
    private let index: [String: (Int, Int)]

    public enum MapShapesError: Error {
        case badMagic
    }

    public init(data: Data) throws {
        let r = BinaryReader(data: data)
        guard r.ascii(0, count: 4) == "WTM1" else { throw MapShapesError.badMagic }
        countryCount = Int(r.u32(4))
        polyCount = Int(r.u32(8))
        ringCount = Int(r.u32(12))

        countriesOff = 20
        polysOff = countriesOff + countryCount * 8
        ringsOff = polysOff + polyCount * 6
        pointsOff = ringsOff + ringCount * 8

        var index: [String: (Int, Int)] = [:]
        for i in 0..<countryCount {
            let base = countriesOff + i * 8
            let code = r.ascii(base, count: 2)
            index[code] = (Int(r.u32(base + 2)), Int(r.u16(base + 6)))
        }
        self.index = index
        self.r = r
    }

    public convenience init(bundle: Bundle) throws {
        var url = bundle.url(forResource: "map110m", withExtension: "bin", subdirectory: "GeoData")
        if url == nil, let base = bundle.resourceURL {
            let candidate = base.appendingPathComponent("GeoData/map110m.bin")
            if FileManager.default.fileExists(atPath: candidate.path) {
                url = candidate
            }
        }
        guard let url else { throw MapShapesError.badMagic }
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    public convenience init() throws {
        try self.init(bundle: Bundle.module)
    }

    public var countryCodes: [String] {
        Array(index.keys)
    }

    /// Outer rings for a country, ready to become map polygons.
    public func rings(forCountry code: String) -> [[GeoPoint]] {
        guard let (firstPoly, count) = index[code] else { return [] }
        var out: [[GeoPoint]] = []
        for pi in firstPoly..<(firstPoly + count) {
            let polyBase = polysOff + pi * 6
            let firstRing = Int(r.u32(polyBase))
            let ringN = Int(r.u16(polyBase + 4))
            for ri in firstRing..<(firstRing + ringN) {
                let ringBase = ringsOff + ri * 8
                let firstPoint = Int(r.u32(ringBase))
                let n = Int(r.u32(ringBase + 4))
                var ring: [GeoPoint] = []
                ring.reserveCapacity(n)
                for k in 0..<n {
                    let off = pointsOff + (firstPoint + k) * 8
                    ring.append(
                        GeoPoint(
                            latitude: Double(r.f32(off + 4)),
                            longitude: Double(r.f32(off))
                        )
                    )
                }
                out.append(ring)
            }
        }
        return out
    }

    /// Rough visual center: bbox center of the largest ring.
    public func centroid(forCountry code: String) -> GeoPoint? {
        let all = rings(forCountry: code)
        guard let largest = all.max(by: { $0.count < $1.count }) else { return nil }
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for p in largest {
            minLat = min(minLat, p.latitude)
            maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude)
            maxLon = max(maxLon, p.longitude)
        }
        return GeoPoint(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
    }
}

/// Great-circle arc sampling (for flight-path overlays).
public func greatCircleArc(from a: GeoPoint, to b: GeoPoint, samples: Int = 32) -> [GeoPoint] {
    let d2r = Double.pi / 180
    let lat1 = a.latitude * d2r, lon1 = a.longitude * d2r
    let lat2 = b.latitude * d2r, lon2 = b.longitude * d2r

    let x1 = cos(lat1) * cos(lon1), y1 = cos(lat1) * sin(lon1), z1 = sin(lat1)
    let x2 = cos(lat2) * cos(lon2), y2 = cos(lat2) * sin(lon2), z2 = sin(lat2)

    let dot = max(-1, min(1, x1 * x2 + y1 * y2 + z1 * z2))
    let omega = acos(dot)
    guard omega > 1e-6 else { return [a, b] }

    var out: [GeoPoint] = []
    out.reserveCapacity(samples + 1)
    for i in 0...samples {
        let t = Double(i) / Double(samples)
        let s1 = sin((1 - t) * omega) / sin(omega)
        let s2 = sin(t * omega) / sin(omega)
        let x = s1 * x1 + s2 * x2
        let y = s1 * y1 + s2 * y2
        let z = s1 * z1 + s2 * z2
        let lat = atan2(z, sqrt(x * x + y * y)) / d2r
        let lon = atan2(y, x) / d2r
        out.append(GeoPoint(latitude: lat, longitude: lon))
    }
    return out
}
