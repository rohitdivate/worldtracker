import Foundation

/// The dot-matrix world: which country owns each dot of a lat/lon grid.
/// Shared by the app's Constellation map and the Your World widget so the
/// two always render the same world.
public enum WorldDotGrid {
    public struct Dot: Sendable, Equatable {
        /// 0…1 across the grid (x: west→east, y: north→south).
        public let unitX: Double
        public let unitY: Double
        public let code: String

        public init(unitX: Double, unitY: Double, code: String) {
            self.unitX = unitX
            self.unitY = unitY
            self.code = code
        }
    }

    /// Land dots only, with their owning country. Poles are cropped like
    /// every world dot-map does.
    public static func compute(
        shapes: WorldMapShapes,
        columns: Int = 66,
        rows: Int = 30,
        latMax: Double = 74,
        latMin: Double = -56
    ) -> [Dot] {
        struct CountryRings {
            let code: String
            let minLat: Double
            let maxLat: Double
            let minLon: Double
            let maxLon: Double
            let rings: [[GeoPoint]]
        }

        var index: [CountryRings] = []
        for code in shapes.countryCodes {
            let rings = shapes.rings(forCountry: code)
            guard !rings.isEmpty else { continue }
            var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
            for ring in rings {
                for point in ring {
                    minLat = min(minLat, point.latitude)
                    maxLat = max(maxLat, point.latitude)
                    minLon = min(minLon, point.longitude)
                    maxLon = max(maxLon, point.longitude)
                }
            }
            index.append(CountryRings(
                code: code,
                minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon,
                rings: rings
            ))
        }

        func pointInRing(_ ring: [GeoPoint], lat: Double, lon: Double) -> Bool {
            guard ring.count > 2 else { return false }
            var inside = false
            var j = ring.count - 1
            for i in 0..<ring.count {
                let a = ring[i]
                let b = ring[j]
                if (a.latitude > lat) != (b.latitude > lat) {
                    let crossing = (b.longitude - a.longitude)
                        * (lat - a.latitude) / (b.latitude - a.latitude) + a.longitude
                    if lon < crossing { inside.toggle() }
                }
                j = i
            }
            return inside
        }

        func owner(lat: Double, lon: Double) -> String? {
            for entry in index {
                guard lat >= entry.minLat, lat <= entry.maxLat,
                      lon >= entry.minLon, lon <= entry.maxLon else { continue }
                // Even-odd across every ring: holes cancel naturally.
                var inside = false
                for ring in entry.rings where pointInRing(ring, lat: lat, lon: lon) {
                    inside.toggle()
                }
                if inside { return entry.code }
            }
            return nil
        }

        var result: [Dot] = []
        for row in 0..<rows {
            let lat = latMax - (Double(row) + 0.5) / Double(rows) * (latMax - latMin)
            for column in 0..<columns {
                let lon = -180.0 + (Double(column) + 0.5) / Double(columns) * 360.0
                if let code = owner(lat: lat, lon: lon) {
                    result.append(Dot(
                        unitX: Double(column) / Double(columns - 1),
                        unitY: Double(row) / Double(rows - 1),
                        code: code
                    ))
                }
            }
        }
        return result
    }
}
