import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Your World" (large) — the dot-map of the year. Land is dim dots;
/// countries you've been to glow, home burns amber. Painted offline from
/// the Kit's bundled 110m outlines — no network, ever.

/// Precomputed once per widget process: which country owns each grid dot.
private enum DotGrid {
    struct Dot {
        let unitX: CGFloat
        let unitY: CGFloat
        let code: String
    }

    static let columns = 66
    static let rows = 30
    // Crop poles like every world dot-map does.
    static let latMax = 74.0
    static let latMin = -56.0

    static let dots: [Dot] = compute()

    private struct CountryRings {
        let code: String
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
        let rings: [[GeoPoint]]
    }

    private static func compute() -> [Dot] {
        guard let shapes = try? WorldMapShapes() else { return [] }

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

        var result: [Dot] = []
        for row in 0..<rows {
            let lat = latMax - (Double(row) + 0.5) / Double(rows) * (latMax - latMin)
            for column in 0..<columns {
                let lon = -180.0 + (Double(column) + 0.5) / Double(columns) * 360.0
                if let code = owner(lat: lat, lon: lon, index: index) {
                    result.append(Dot(
                        unitX: CGFloat(column) / CGFloat(columns - 1),
                        unitY: CGFloat(row) / CGFloat(rows - 1),
                        code: code
                    ))
                }
            }
        }
        return result
    }

    private static func owner(lat: Double, lon: Double, index: [CountryRings]) -> String? {
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

    private static func pointInRing(_ ring: [GeoPoint], lat: Double, lon: Double) -> Bool {
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
}

struct YourWorldWidgetView: View {
    var entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://map"))
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let visited = Dictionary(
            uniqueKeysWithValues: snapshot.countries.map { ($0.code, $0.days) }
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR WORLD · \(String(snapshot.year))")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(WTheme.aurora1)
                Spacer()
                if let code = snapshot.currentCountry {
                    Text("\(flagEmoji(code)) Day \(max(1, snapshot.dayOfStay))")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WTheme.amber)
                }
            }

            dotMap(visited: visited, home: snapshot.homeCountry)
                .frame(maxHeight: .infinity)

            HStack(spacing: 0) {
                stat(value: "\(snapshot.countriesThisYear)", label: "COUNTRIES")
                stat(value: "\(snapshot.travelDaysThisYear)", label: "TRAVEL DAYS")
                stat(
                    value: "\(Int((Double(snapshot.countriesThisYear) / 195.0 * 100).rounded()))%",
                    label: "OF THE WORLD"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dotMap(visited: [String: Int], home: String?) -> some View {
        Canvas { context, size in
            let dots = DotGrid.dots
            guard !dots.isEmpty else { return }
            let maxDays = visited.values.max() ?? 1
            let radius = min(
                size.width / CGFloat(DotGrid.columns) * 0.32,
                size.height / CGFloat(DotGrid.rows) * 0.32
            )

            for dot in dots {
                let color: Color
                if dot.code == home {
                    color = WTheme.amber
                } else if let days = visited[dot.code] {
                    color = WTheme.aurora1.opacity(0.55 + 0.45 * Double(days) / Double(maxDays))
                } else {
                    color = WTheme.ink3.opacity(0.32)
                }
                let center = CGPoint(
                    x: dot.unitX * size.width,
                    y: dot.unitY * size.height
                )
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )),
                    with: .color(color)
                )
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.auroraGradient)
            Text(label)
                .font(.system(size: 7.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(WTheme.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("🌍").font(.system(size: 34))
            Text(widgetEmptyMessage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct YourWorldWidget: Widget {
    let kind = "YourWorldWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            YourWorldWidgetView(entry: entry)
        }
        .configurationDisplayName("Your World")
        .description("The dot-map of everywhere you've been this year.")
        .supportedFamilies([.systemLarge])
    }
}
