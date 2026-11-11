import Foundation

/// One country's page in the passport: when it was first and last seen, how
/// long in total, how many separate stays.
public struct PassportStamp: Sendable, Equatable, Identifiable, Codable {
    public var id: String { code }
    public let code: String
    public let firstDay: Int
    public let lastDay: Int
    /// Any-presence days, the same count every other screen shows.
    public let totalDays: Int
    /// Separate runs of consecutive days.
    public let visits: Int
    public let continent: Continent?

    public init(
        code: String, firstDay: Int, lastDay: Int,
        totalDays: Int, visits: Int, continent: Continent?
    ) {
        self.code = code
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.totalDays = totalDays
        self.visits = visits
        self.continent = continent
    }
}

/// Derives the stamp collection from resolved days. Like trips, stamps are
/// computed, never stored: editing a day re-inks the passport for free.
public enum PassportBook {
    /// Newest first-visit first, so a fresh stamp lands at the front.
    public static func stamps(from days: [ResolvedDay]) -> [PassportStamp] {
        struct Entry {
            var first: Int
            var last: Int
            var total = 0
            var visits = 0
        }
        var entries: [String: Entry] = [:]

        for day in days {
            for code in day.countryCodes {
                if var entry = entries[code] {
                    // A gap of more than one day since the last sighting
                    // starts a new stay.
                    if day.day > entry.last + 1 { entry.visits += 1 }
                    if day.day != entry.last { entry.total += 1 }
                    entry.last = max(entry.last, day.day)
                    entries[code] = entry
                } else {
                    entries[code] = Entry(first: day.day, last: day.day, total: 1, visits: 1)
                }
            }
        }

        return entries
            .map { code, entry in
                PassportStamp(
                    code: code,
                    firstDay: entry.first,
                    lastDay: entry.last,
                    totalDays: entry.total,
                    visits: entry.visits,
                    continent: ContinentTable.continent(of: code)
                )
            }
            .sorted { ($0.firstDay, $1.code) > ($1.firstDay, $0.code) }
    }
}

/// A country the user wants to visit, and whether the ledger says they have.
public struct WishlistEntry: Sendable, Equatable, Identifiable {
    public var id: String { code }
    public let code: String
    public let visitedOn: Int?

    public var isVisited: Bool { visitedOn != nil }

    public init(code: String, visitedOn: Int?) {
        self.code = code
        self.visitedOn = visitedOn
    }
}

public enum Wishlist {
    /// Unvisited first (alphabetical by code), then visited, most recent
    /// first: the list reads as "still to do", then "done".
    public static func entries(codes: [String], stamps: [PassportStamp]) -> [WishlistEntry] {
        let firstVisit = Dictionary(uniqueKeysWithValues: stamps.map { ($0.code, $0.firstDay) })
        var seen: Set<String> = []
        let unique = codes.filter { seen.insert($0).inserted }
        return unique
            .map { WishlistEntry(code: $0, visitedOn: firstVisit[$0]) }
            .sorted { a, b in
                switch (a.visitedOn, b.visitedOn) {
                case (nil, nil): return a.code < b.code
                case (nil, _): return true
                case (_, nil): return false
                case let (x?, y?): return (x, b.code) > (y, a.code)
                }
            }
    }
}
