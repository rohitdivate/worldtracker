import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Your World" (large) — the dot-map of the year. Land is dim dots;
/// countries you've been to glow, home burns amber. Painted offline from
/// the Kit's bundled 110m outlines — no network, ever.

/// Precomputed once per widget process, from the shared Kit painter.
private enum DotGrid {
    static let columns = 66
    static let rows = 30

    static let dots: [WorldDotGrid.Dot] = {
        guard let shapes = try? WorldMapShapes() else { return [] }
        return WorldDotGrid.compute(shapes: shapes, columns: columns, rows: rows)
    }()
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
                .overlay(alignment: .bottomTrailing) {
                    WTheme.Wordmark()
                }

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
                    x: CGFloat(dot.unitX) * size.width,
                    y: CGFloat(dot.unitY) * size.height
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
