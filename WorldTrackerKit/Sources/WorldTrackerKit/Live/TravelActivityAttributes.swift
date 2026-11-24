#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// The travel Live Activity's contract, defined once in the Kit so the app
/// (which starts/updates it) and the widget extension (which renders it)
/// agree by construction. A new country = a new activity, so the country
/// lives in the fixed attributes and only the counters flow as state.
public struct TravelActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Day N of the current stay.
        public var dayOfStay: Int
        /// Days spent in this country this calendar year.
        public var daysThisYear: Int
        /// Countries visited this year — the trip-dots row.
        public var countriesThisYear: Int

        // The day limit this stay is counting toward, if any. All optional:
        // an activity started by an older build decodes without them, and a
        // stay with no rule simply shows the classic banner.

        /// Rule name, e.g. "Schengen 90/180".
        public var limitName: String?
        public var limitUsed: Int?
        public var limitMax: Int?
        /// "56 days left" / "At the limit" / "3 days over".
        public var limitHeadline: String?
        /// `DayLimitStatus.Level` raw value, for the bar's colour.
        public var limitLevel: String?

        public init(
            dayOfStay: Int,
            daysThisYear: Int,
            countriesThisYear: Int,
            limitName: String? = nil,
            limitUsed: Int? = nil,
            limitMax: Int? = nil,
            limitHeadline: String? = nil,
            limitLevel: String? = nil
        ) {
            self.dayOfStay = dayOfStay
            self.daysThisYear = daysThisYear
            self.countriesThisYear = countriesThisYear
            self.limitName = limitName
            self.limitUsed = limitUsed
            self.limitMax = limitMax
            self.limitHeadline = limitHeadline
            self.limitLevel = limitLevel
        }

        /// 0…1 progress toward the limit, nil when no rule applies.
        public var limitFraction: Double? {
            guard let used = limitUsed, let max = limitMax, max > 0 else { return nil }
            return min(1, Swift.max(0, Double(used) / Double(max)))
        }
    }

    public var countryCode: String

    public init(countryCode: String) {
        self.countryCode = countryCode
    }
}
#endif
