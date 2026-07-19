import SwiftUI
import WorldTrackerKit

/// A month of flags as a card — 12 shareable artifacts a year, for free.
/// Reuses the calendar's pure DayCellView inside a STATIC Grid (ImageRenderer
/// never sees a lazy container).
struct MonthShareCard: View {
    let month: MonthSpec
    let days: [ResolvedDay]
    let todayEpoch: Int
    /// Unique visited countries in first-appearance order.
    let countries: [String]
    let travelDays: Int

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(month.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.auroraGradient)
                    Text(String(month.year))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink2)
                }

                grid
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                if !countries.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(countries.prefix(9), id: \.self) { code in
                            Text(flagEmoji(code)).font(.system(size: 19))
                        }
                        Text("\(travelDays) travel \(travelDays == 1 ? "day" : "days")")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.aurora1)
                            .padding(.leading, 4)
                    }
                    .padding(.top, 16)
                }

                Spacer()

                ShareWordmark(withHook: true)
                    .padding(.bottom, 22)
            }
        }
        .frame(width: 360, height: 480)
    }

    /// Monday-first cells: leading blanks, then the month's days.
    private var cells: [ResolvedDay?] {
        Array(repeating: nil, count: month.leadingBlanks) + days.map(Optional.some)
    }

    private var grid: some View {
        let cells = cells
        let rowCount = (cells.count + 6) / 7
        return Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                ForEach(0..<7, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
            ForEach(0..<rowCount, id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column
                        if index < cells.count, let day = cells[index] {
                            DayCellView(
                                resolved: day,
                                dayNumber: day.day - month.firstEpochDay + 1,
                                isToday: false,
                                isFuture: day.day > todayEpoch
                            )
                            .frame(width: 40)
                        } else {
                            Color.clear.frame(width: 40, height: 44)
                        }
                    }
                }
            }
        }
    }
}
