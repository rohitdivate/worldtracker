import SwiftUI
import WorldTrackerKit

/// The whole world on one card: the dot-map with every visited country lit,
/// plus the numbers that make people ask "what app is that?"
struct WorldShareCard: View {
    let dots: [WorldDotGrid.Dot]
    let visited: [String: Int]
    let home: String?
    let travelDays: Int

    private static let columns = 66
    private static let rows = 30

    private var countriesCount: Int { visited.count }

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 0) {
                Spacer().frame(height: 26)

                Text("MY WORLD")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(Theme.aurora1)

                dotMap
                    .frame(width: 324, height: 152)
                    .padding(.top, 16)

                HStack(spacing: 0) {
                    ShareStat(value: "\(countriesCount)", label: "COUNTRIES")
                    ShareStat(
                        value: "\(Int((Double(countriesCount) / 195.0 * 100).rounded()))%",
                        label: "OF THE WORLD",
                        color: Theme.amber
                    )
                    ShareStat(value: "\(travelDays)", label: "TRAVEL DAYS")
                }
                .padding(.top, 18)
                .padding(.horizontal, 26)

                Spacer()

                ShareWordmark(withHook: true)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 360, height: 360)
    }

    private var dotMap: some View {
        Canvas { context, size in
            guard !dots.isEmpty else { return }
            let maxDays = visited.values.max() ?? 1
            let radius = min(
                size.width / CGFloat(Self.columns) * 0.32,
                size.height / CGFloat(Self.rows) * 0.32
            )
            for dot in dots {
                let color: Color
                if dot.code == home {
                    color = Theme.amber
                } else if let days = visited[dot.code] {
                    color = Theme.aurora1.opacity(0.55 + 0.45 * Double(days) / Double(maxDays))
                } else {
                    color = Theme.ink3.opacity(0.32)
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
}
