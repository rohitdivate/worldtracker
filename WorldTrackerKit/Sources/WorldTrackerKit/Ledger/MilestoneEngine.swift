import Foundation

/// The lifetime numbers milestone detection runs on — tiny, Codable, stored
/// between evaluations.
public struct MilestoneSnapshot: Sendable, Equatable, Codable {
    public let distinctCountries: Int
    public let lifetimeTravelDays: Int
    public let longestTripDays: Int
    public let longestTripStartDay: Int?

    public init(
        distinctCountries: Int,
        lifetimeTravelDays: Int,
        longestTripDays: Int,
        longestTripStartDay: Int?
    ) {
        self.distinctCountries = distinctCountries
        self.lifetimeTravelDays = lifetimeTravelDays
        self.longestTripDays = longestTripDays
        self.longestTripStartDay = longestTripStartDay
    }

    public static let zero = MilestoneSnapshot(
        distinctCountries: 0, lifetimeTravelDays: 0,
        longestTripDays: 0, longestTripStartDay: nil
    )
}

public enum Milestone: Sendable, Hashable, Codable {
    case countryCount(Int)
    case travelDays(Int)
    /// Crossed when countries × 100 ≥ percent × 195.
    case worldPercent(Int)
    case longestTripBeaten(days: Int, startDay: Int)

    /// Stable once-ever dedupe key.
    public var storageKey: String {
        switch self {
        case .countryCount(let n): return "milestone-countries-\(n)"
        case .travelDays(let n): return "milestone-days-\(n)"
        case .worldPercent(let p): return "milestone-world-\(p)"
        case .longestTripBeaten(_, let start): return "milestone-longtrip-\(start)"
        }
    }
}

/// Pure crossing detection: which milestones does `after` hold that `before`
/// didn't? Presentation-ordered so callers can collapse a bulk crossing to
/// the first element.
public enum MilestoneEngine {
    public static let worldCountryCount = 195
    public static let countryThresholds = [5, 10, 15, 20, 25, 30, 40, 50, 75, 100]
    public static let travelDayThresholds = [50, 100, 250, 500, 1000]
    public static let worldPercentThresholds = [10, 25, 50]

    /// Order: countryCount > worldPercent > travelDays > longestTripBeaten,
    /// largest threshold first within each family.
    public static func crossed(
        before: MilestoneSnapshot, after: MilestoneSnapshot
    ) -> [Milestone] {
        var result: [Milestone] = []

        for threshold in countryThresholds.reversed()
        where before.distinctCountries < threshold && after.distinctCountries >= threshold {
            result.append(.countryCount(threshold))
        }

        for percent in worldPercentThresholds.reversed() {
            let heldBefore = before.distinctCountries * 100 >= percent * worldCountryCount
            let holdsAfter = after.distinctCountries * 100 >= percent * worldCountryCount
            if !heldBefore && holdsAfter {
                result.append(.worldPercent(percent))
            }
        }

        for threshold in travelDayThresholds.reversed()
        where before.lifetimeTravelDays < threshold && after.lifetimeTravelDays >= threshold {
            result.append(.travelDays(threshold))
        }

        // Any increase over a real previous best. A first-ever trip (0 → N)
        // is not a "beaten" record, so it never fires.
        if before.longestTripDays > 0,
           after.longestTripDays > before.longestTripDays,
           let start = after.longestTripStartDay {
            result.append(.longestTripBeaten(days: after.longestTripDays, startDay: start))
        }

        return result
    }
}
