#if canImport(ActivityKit)
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

        public init(dayOfStay: Int, daysThisYear: Int, countriesThisYear: Int) {
            self.dayOfStay = dayOfStay
            self.daysThisYear = daysThisYear
            self.countriesThisYear = countriesThisYear
        }
    }

    public var countryCode: String

    public init(countryCode: String) {
        self.countryCode = countryCode
    }
}
#endif
