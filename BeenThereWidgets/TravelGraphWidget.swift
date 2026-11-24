import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Travel Graph" — the year as a heatmap. Medium is the week-aligned strip
/// the app's Home card shows (same `YearGrid` layout); large lays the year
/// out as twelve small calendars.
struct TravelGraphWidgetView: View {
    var entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, !snapshot.tones.isEmpty {
                if family == .systemLarge {
                    large(snapshot)
                } else {
                    medium(snapshot)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://calendar"))
    }

    private func header(_ snapshot: WidgetSnapshot) -> some View {
        HStack {
            WLabel(text: "Travel graph · \(String(snapshot.year))")
            Spacer()
            Text("\(snapshot.travelDaysThisYear) travel days")
                .font(WTheme.figure(9.5, weight: .bold))
                .foregroundStyle(WTheme.amber)
        }
    }

    // MARK: - Medium: week-aligned strip

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        let grid = YearGrid(year: snapshot.year)
        let tones = snapshot.tones

        return VStack(alignment: .leading, spacing: 6) {
            header(snapshot)

            Canvas { context, size in
                // 53 columns across a medium widget leaves each day about
                // 6pt wide, so the cells grow downward to use the height:
                // the strip reads as a row of capsules rather than a thin
                // band with dead space under it.
                let cellW = size.width / CGFloat(grid.columns)
                let labelHeight: CGFloat = 10
                let cellH = min((size.height - labelHeight) / 7, cellW * 2)
                let yInset = max(0, (size.height - labelHeight - cellH * 7) / 2)
                let w = cellW * 0.8
                let h = cellH * 0.84

                for mark in grid.months {
                    context.draw(
                        Text(Self.initials[mark.month - 1])
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(WTheme.ink3),
                        at: CGPoint(
                            x: CGFloat(mark.column) * cellW + cellW / 2,
                            y: yInset + labelHeight / 2 - 1
                        )
                    )
                }
                for info in grid.cells {
                    let tone = info.dayIndex < tones.count ? tones[info.dayIndex] : .future
                    let rect = CGRect(
                        x: CGFloat(info.column) * cellW + (cellW - w) / 2,
                        y: yInset + labelHeight + CGFloat(info.row) * cellH + (cellH - h) / 2,
                        width: w, height: h
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: w * 0.3),
                        with: .color(WTone.color(tone))
                    )
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                legend(.away, "Away")
                legend(.crossing, "Border")
                legend(.home, "Home")
                Spacer()
                Text("\(snapshot.countriesThisYear) countries")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WTheme.ink3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let initials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private func legend(_ tone: DayTone, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(WTone.color(tone))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(WTheme.ink3)
        }
    }

    // MARK: - Large: twelve small calendars

    private func large(_ snapshot: WidgetSnapshot) -> some View {
        let tones = snapshot.tones
        let year = snapshot.year
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
        let names = DateFormatter().shortMonthSymbols ?? []

        return VStack(alignment: .leading, spacing: 10) {
            header(snapshot)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...12, id: \.self) { month in
                    let first = EpochDay.daysFromCivil(year: year, month: month, day: 1)
                    let next = month == 12
                        ? EpochDay.daysFromCivil(year: year + 1, month: 1, day: 1)
                        : EpochDay.daysFromCivil(year: year, month: month + 1, day: 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text((month <= names.count ? names[month - 1] : "").uppercased())
                            .font(WTheme.label(7.5, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(WTheme.ink3)
                        monthGrid(
                            lead: YearGrid.weekdayIndex(first),
                            length: next - first,
                            offset: first - jan1,
                            tones: tones
                        )
                        .aspectRatio(7.0 / 6.0, contentMode: .fit)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                legend(.away, "Away")
                legend(.crossing, "Border day")
                legend(.home, "Home")
                Spacer()
                Text("\(snapshot.countriesThisYear) countries")
                    .font(WTheme.figure(9, weight: .bold))
                    .foregroundStyle(WTheme.aurora1)
                WTheme.Wordmark()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func monthGrid(lead: Int, length: Int, offset: Int, tones: [DayTone]) -> some View {
        Canvas { context, size in
            let cell = min(size.width / 7, size.height / 6)
            let dot = cell * 0.74
            let inset = (cell - dot) / 2
            for day in 0..<length {
                let slot = lead + day
                let index = offset + day
                let tone = index < tones.count ? tones[index] : .future
                let rect = CGRect(
                    x: CGFloat(slot % 7) * cell + inset,
                    y: CGFloat(slot / 7) * cell + inset,
                    width: dot, height: dot
                )
                context.fill(Path(ellipseIn: rect), with: .color(WTone.color(tone)))
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundStyle(WTheme.aurora1)
            Text(widgetEmptyMessage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TravelGraphWidget: Widget {
    let kind = "TravelGraphWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            TravelGraphWidgetView(entry: entry)
        }
        .configurationDisplayName("Travel Graph")
        .description("Your year as a heatmap: every travel day lit.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
