import Foundation

/// What to do with each day that LEAVES a trip when its range shrinks,
/// moves, or the trip is deleted. Removing the manual facts alone is not
/// enough: automatic evidence (gps/photo) would resurface the country, and
/// gap-fill would re-extend the trip through the emptied days. Each removed
/// day must either be marked "no data" or keep only its other countries.
///
/// Computed from PRE-EDIT resolved verdicts, before anything is written.
public struct TripEditPlan: Sendable, Equatable {
    /// A border day the trip is leaving: the other countries remain, pinned
    /// as manual facts so the removed one can't resurface from evidence.
    public struct DayOverride: Sendable, Equatable {
        public let day: Int
        public let countryCodes: [String]

        public init(day: Int, countryCodes: [String]) {
            self.day = day
            self.countryCodes = countryCodes
        }
    }

    /// The ORIGINAL trip country — the one leaving the removed days (the
    /// editor may simultaneously change the trip to a different country).
    public let countryCode: String
    /// Days that showed only this country, or nothing at all (gap-filled or
    /// already cleared): marked "no data" so evidence and gap-fill can't
    /// rebuild the old range. Ascending.
    public let clearDays: [Int]
    /// Border days, ascending.
    public let overrideDays: [DayOverride]

    public var isEmpty: Bool { clearDays.isEmpty && overrideDays.isEmpty }

    public init(countryCode: String, clearDays: [Int], overrideDays: [DayOverride]) {
        self.countryCode = countryCode
        self.clearDays = clearDays
        self.overrideDays = overrideDays
    }
}

/// Buckets the days a trip edit removes. Pure so the rules live in one
/// place, run on Linux, and back both the editor (shrink/move) and the
/// delete path.
public enum TripEditPlanner {
    /// - Parameters:
    ///   - countryCode: the trip's country before the edit.
    ///   - originalRange: the trip's day range before the edit.
    ///   - newRange: the range the trip keeps; nil means deletion (every
    ///     day is removed).
    ///   - resolvedCodes: PRE-EDIT verdict for a day, resolved without
    ///     neighbors (single-day resolution: gap-fill contributes nothing,
    ///     so a day carried only by fill yields []).
    public static func plan(
        removingCountry countryCode: String,
        from originalRange: ClosedRange<Int>,
        keeping newRange: ClosedRange<Int>?,
        resolvedCodes: (Int) -> [String]
    ) -> TripEditPlan {
        var clearDays: [Int] = []
        var overrideDays: [TripEditPlan.DayOverride] = []

        for day in originalRange where newRange?.contains(day) != true {
            let codes = resolvedCodes(day)
            if codes.isEmpty || codes == [countryCode] {
                // Solo or evidence-free (gap-filled / already-cleared) day:
                // "no data". Clearing also fences assume-stayed from
                // re-extending the trip past its new end, and re-clearing
                // an already-cleared day is a no-op.
                clearDays.append(day)
            } else if codes.contains(countryCode) {
                // Border day: the other countries survive, in their
                // evidence-weight order.
                overrideDays.append(
                    TripEditPlan.DayOverride(
                        day: day,
                        countryCodes: codes.filter { $0 != countryCode }
                    )
                )
            }
            // Days that never showed this country are left untouched.
        }

        return TripEditPlan(
            countryCode: countryCode,
            clearDays: clearDays,
            overrideDays: overrideDays
        )
    }
}
