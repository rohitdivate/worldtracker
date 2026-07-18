import Foundation

/// A calendar day identified by its count of days since 1970-01-01 (proleptic
/// Gregorian). The crucial rule of the whole app: a moment is bucketed into a
/// day using the timezone OF THE PLACE the sample belongs to — never the
/// device timezone — so evening photos in Tokyo never land on "yesterday".
public struct EpochDay: Hashable, Comparable, Sendable, Codable {
    public let value: Int

    public init(value: Int) {
        self.value = value
    }

    /// Bucket an instant into a day using the given (place-local) timezone.
    public init(date: Date, timeZone: TimeZone) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        self.value = Self.daysFromCivil(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func < (lhs: EpochDay, rhs: EpochDay) -> Bool {
        lhs.value < rhs.value
    }

    /// Howard Hinnant's days-from-civil algorithm (public domain).
    public static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        var y = year
        if month <= 2 { y -= 1 }
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month + (month > 2 ? -3 : 9)
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    /// Inverse of `daysFromCivil`.
    public func civil() -> (year: Int, month: Int, day: Int) {
        var z = value
        z += 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        var y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        if m <= 2 { y += 1 }
        return (y, m, d)
    }

    /// Midnight at the start of this day in the given timezone.
    public func startDate(in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let (y, m, d) = civil()
        return cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date(timeIntervalSince1970: 0)
    }
}

/// Where a fact about a day came from. Precedence when resolving a day:
/// manual > gps/visit > photo > timezoneHint.
public enum FactSource: String, Sendable, Codable, CaseIterable {
    case gps
    case visit
    case photo
    case manual
    case timezoneHint
}
