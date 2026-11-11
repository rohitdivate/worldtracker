import Foundation
import Observation
import WorldTrackerKit

/// Lifetime insights, stamps, continents and badges, computed once per
/// ledger change and shared by Home, Passport, the widget snapshot and
/// Siri. All of it is derived; nothing here is persisted.
@MainActor
@Observable
final class InsightsStore {
    struct Summary {
        let insights: TravelInsights
        let stamps: [PassportStamp]
        let continents: [ContinentProgress]
        let achievements: [Achievement]
        let wishlist: [WishlistEntry]
        let extremes: CityExtremes

        var unlockedCount: Int { achievements.filter(\.isUnlocked).count }
        /// The locked badge closest to unlocking.
        var nextAchievement: Achievement? {
            achievements.filter { !$0.isUnlocked }.max { $0.fraction < $1.fraction }
        }
        var continentsVisited: Int { continents.filter { $0.visited > 0 }.count }
    }

    /// Bumped when the coordinate sources finish loading, so views that read
    /// `summary` re-render with real distances.
    private(set) var revision = 0

    /// Wishlist country codes, in the order they were added.
    private(set) var wishlistCodes: [String]

    @ObservationIgnored private var cities: [CityDays] = []
    @ObservationIgnored private var shapes: WorldMapShapes?
    @ObservationIgnored private var cacheKey = ""
    @ObservationIgnored private var cache: Summary?
    @ObservationIgnored private var loadedToken = -1

    private static let wishlistKey = "wishlistCountries"

    init() {
        wishlistCodes = UserDefaults.standard.stringArray(forKey: Self.wishlistKey) ?? []
    }

    // MARK: - Wishlist

    func isWished(_ code: String) -> Bool { wishlistCodes.contains(code) }

    func toggleWish(_ code: String) {
        if let index = wishlistCodes.firstIndex(of: code) {
            wishlistCodes.remove(at: index)
        } else {
            wishlistCodes.append(code)
        }
        UserDefaults.standard.set(wishlistCodes, forKey: Self.wishlistKey)
        cacheKey = ""
    }

    // MARK: - Coordinates

    /// Loads the outline atlas (once) and the user's visited cities (per
    /// ledger change). Distances are zero until this has run.
    func warm(store: LedgerStore) async {
        let token = store.changeToken
        guard token != loadedToken || shapes == nil else { return }
        if shapes == nil {
            shapes = try? await Task.detached(priority: .utility) { try WorldMapShapes() }.value
        }
        cities = await AppContainer.shared.placesEngine.visitedCityDays()
        loadedToken = token
        cacheKey = ""
        revision += 1
        // Distances just became real; the widgets carry them too.
        SharedSnapshotStore.write(from: store)
    }

    /// One point per country: where the user actually spent the most days
    /// there if we know, else the centre of the outline.
    private func coordinateLookup() -> (String) -> GeoPoint? {
        var best: [String: CityDays] = [:]
        for city in cities {
            guard let code = city.countryCode else { continue }
            if city.days > (best[code]?.days ?? 0) { best[code] = city }
        }
        let shapes = shapes
        var memo: [String: GeoPoint?] = [:]
        return { code in
            if let hit = memo[code] { return hit }
            let point: GeoPoint?
            if let city = best[code] {
                point = GeoPoint(latitude: city.latitude, longitude: city.longitude)
            } else {
                point = shapes?.centroid(forCountry: code)
            }
            memo[code] = point
            return point
        }
    }

    // MARK: - Summary

    func summary(using store: LedgerStore) -> Summary {
        let today = store.todayEpoch
        let key = "\(store.changeToken)-\(today)-\(revision)-\(wishlistCodes.joined())"
        if key == cacheKey, let cache { return cache }

        let earliest = min(store.earliestDay ?? today, today)
        let days = store.resolvedDays(in: earliest...today)
        let insights = TravelInsightsEngine.compute(
            days: days,
            homeTimeline: store.homeTimeline,
            today: today,
            coordinate: coordinateLookup()
        )
        let stamps = PassportBook.stamps(from: days)
        let wishlist = Wishlist.entries(codes: wishlistCodes, stamps: stamps)
        let summary = Summary(
            insights: insights,
            stamps: stamps,
            continents: ContinentProgress.compute(visited: Set(stamps.map(\.code))),
            achievements: AchievementEngine.evaluate(
                AchievementEngine.input(
                    insights: insights,
                    stamps: stamps,
                    wishlistVisited: wishlist.filter(\.isVisited).count
                )
            ),
            wishlist: wishlist,
            extremes: CityExtremes.compute(cities)
        )
        cache = summary
        cacheKey = key
        return summary
    }
}
