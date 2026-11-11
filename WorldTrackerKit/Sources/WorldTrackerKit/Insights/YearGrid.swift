import Foundation

/// Week-aligned layout for a year heatmap: one column per week, Monday at
/// the top, the way contribution graphs are drawn. Shared by the Home card
/// and the Travel Graph widget so both put a given day in the same cell.
public struct YearGrid: Sendable, Equatable {
    public struct Cell: Sendable, Equatable {
        /// 0-based day of the year.
        public let dayIndex: Int
        public let epochDay: Int
        public let column: Int
        /// 0 = Monday … 6 = Sunday.
        public let row: Int
    }

    public struct MonthMark: Sendable, Equatable {
        /// 1…12
        public let month: Int
        /// Column holding the 1st of the month.
        public let column: Int
    }

    public let year: Int
    public let columns: Int
    public let cells: [Cell]
    public let months: [MonthMark]

    public static let rows = 7

    public init(year: Int) {
        self.year = year
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let nextJan1 = EpochDay.daysFromCivil(year: year + 1, month: 1, day: 1)
        let length = nextJan1 - jan1
        let lead = Self.weekdayIndex(jan1)

        var cells: [Cell] = []
        cells.reserveCapacity(length)
        for index in 0..<length {
            let slot = lead + index
            cells.append(Cell(
                dayIndex: index, epochDay: jan1 + index,
                column: slot / 7, row: slot % 7
            ))
        }
        self.cells = cells
        self.columns = (lead + length + 6) / 7

        self.months = (1...12).map { month in
            let first = EpochDay.daysFromCivil(year: year, month: month, day: 1)
            return MonthMark(month: month, column: (lead + first - jan1) / 7)
        }
    }

    /// 0 = Monday. 1970-01-01 was a Thursday.
    public static func weekdayIndex(_ epochDay: Int) -> Int {
        (((epochDay + 3) % 7) + 7) % 7
    }
}

/// What a heatmap cell shows for one day.
public enum DayTone: String, Sendable, Codable {
    /// No verdict.
    case unknown
    /// Exclusively in that day's home country.
    case home
    /// Away from home.
    case away
    /// Away, on a day that touched two or more countries.
    case crossing
    /// After today.
    case future

    public static func tone(for day: ResolvedDay, home: String?) -> DayTone {
        guard !day.countryCodes.isEmpty else { return .unknown }
        if day.countryCodes == [home].compactMap({ $0 }) { return .home }
        return day.countryCodes.count > 1 ? .crossing : .away
    }
}
