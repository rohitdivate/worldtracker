import SwiftUI
import WorldTrackerKit

/// The year as a week-aligned grid: home days dim, travel days lit, border
/// days in the second accent. Same layout as the Travel Graph widget, via
/// the Kit's `YearGrid`.
struct YearHeatmapCard: View {
    let year: Int
    /// Tone for each day of the year, Jan 1 first; days after today are
    /// `.future`.
    let tones: [DayTone]
    let travelDays: Int
    let countries: Int

    private var grid: YearGrid { YearGrid(year: year) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(Theme.display(20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(travelDays) travel \(travelDays == 1 ? "day" : "days") · \(countries) \(countries == 1 ? "country" : "countries")")
                    .font(Theme.numeric(11, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }

            YearHeatmap(grid: grid, tones: tones)
                .aspectRatio(CGFloat(grid.columns) / (CGFloat(YearGrid.rows) + 1.6), contentMode: .fit)

            HStack(spacing: 12) {
                legend(HeatmapPalette.color(.home), "Home")
                legend(HeatmapPalette.color(.away), "Away")
                legend(HeatmapPalette.color(.crossing), "Border day")
                legend(HeatmapPalette.color(.unknown), "No data")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(year)): \(travelDays) travel days across \(countries) countries")
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
        }
    }
}

enum HeatmapPalette {
    static func color(_ tone: DayTone) -> Color {
        switch tone {
        case .home: Theme.ink3.opacity(0.42)
        case .away: Theme.aurora1
        case .crossing: Theme.aurora2
        case .unknown: Theme.ink3.opacity(0.16)
        case .future: Theme.ink3.opacity(0.07)
        }
    }
}

/// The grid itself, with month initials along the top.
struct YearHeatmap: View {
    let grid: YearGrid
    let tones: [DayTone]

    private static let initials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(grid.columns)
            let labelHeight = cell * 1.6
            let square = cell * 0.78
            let inset = (cell - square) / 2

            for mark in grid.months {
                let text = Text(Self.initials[mark.month - 1])
                    .font(.system(size: max(7, cell * 1.05), weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                context.draw(
                    text,
                    at: CGPoint(x: CGFloat(mark.column) * cell + cell / 2, y: labelHeight / 2 - 1),
                    anchor: .center
                )
            }

            for cellInfo in grid.cells {
                let tone = cellInfo.dayIndex < tones.count ? tones[cellInfo.dayIndex] : .future
                let rect = CGRect(
                    x: CGFloat(cellInfo.column) * cell + inset,
                    y: labelHeight + CGFloat(cellInfo.row) * cell + inset,
                    width: square,
                    height: square
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: square * 0.26),
                    with: .color(HeatmapPalette.color(tone))
                )
            }
        }
    }
}
