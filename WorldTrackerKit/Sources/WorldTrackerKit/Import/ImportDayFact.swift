import Foundation

/// The unified output of every bulk-import pipeline (Timeline, flights):
/// one aggregated (day, country) observation with evidence weight.
public struct ImportDayFact: Sendable, Equatable {
    public let day: Int            // EpochDay.value
    public let countryCode: String
    public let evidenceCount: Int
    public let first: Date
    public let last: Date

    public init(day: Int, countryCode: String, evidenceCount: Int, first: Date, last: Date) {
        self.day = day
        self.countryCode = countryCode
        self.evidenceCount = evidenceCount
        self.first = first
        self.last = last
    }
}
