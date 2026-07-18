import SwiftUI
import WorldTrackerKit

/// The time windows shared by Home and the trip list.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case thisYear
    case last365
    case lastYear
    case allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisYear: return "This year"
        case .last365: return "Last 365"
        case .lastYear: return "Last year"
        case .allTime: return "All time"
        }
    }

    /// Epoch-day range for the window (needs today + the earliest data day).
    func range(today: Int, earliest: Int?) -> ClosedRange<Int> {
        let (year, _, _) = EpochDay(value: today).civil()
        switch self {
        case .thisYear:
            return EpochDay.daysFromCivil(year: year, month: 1, day: 1)...today
        case .last365:
            return (today - 364)...today
        case .lastYear:
            let start = EpochDay.daysFromCivil(year: year - 1, month: 1, day: 1)
            let end = EpochDay.daysFromCivil(year: year, month: 1, day: 1) - 1
            return start...end
        case .allTime:
            let start = min(earliest ?? today, today)
            return start...today
        }
    }
}

struct PeriodChips: View {
    @Binding var selection: StatsPeriod

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatsPeriod.allCases) { period in
                    Button {
                        withAnimation(.spring(duration: 0.35)) {
                            selection = period
                        }
                    } label: {
                        Text(period.label)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    selection == period
                                        ? AnyShapeStyle(Theme.auroraGradient)
                                        : AnyShapeStyle(Theme.card)
                                )
                            )
                            .foregroundStyle(selection == period ? Theme.sky : Theme.ink2)
                            .overlay(
                                Capsule().strokeBorder(
                                    selection == period ? Color.clear : Theme.hairline2,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

/// Shared date formatting for epoch days.
enum DayFormat {
    static func shortRange(_ startDay: Int, _ endDay: Int, todayYear: Int) -> String {
        let s = EpochDay(value: startDay).civil()
        let e = EpochDay(value: endDay).civil()
        let months = DateFormatter().shortMonthSymbols ?? []
        func fmt(_ c: (year: Int, month: Int, day: Int)) -> String {
            let m = months[c.month - 1].uppercased()
            return c.year == todayYear ? "\(m) \(c.day)" : "\(m) \(c.day) \(c.year)"
        }
        if startDay == endDay { return fmt(s) }
        return "\(fmt(s)) – \(fmt(e))"
    }
}
