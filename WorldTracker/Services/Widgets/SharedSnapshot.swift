import Foundation
import WidgetKit
import WorldTrackerKit

/// The app→widget bridge: one small JSON in the App Group container,
/// rewritten on every ledger change. BeenThereWidgets/WidgetSnapshot.swift
/// mirrors this Codable shape — keep the two in sync.
struct SharedSnapshot: Codable {
    struct CountryDays: Codable {
        let code: String
        let days: Int
    }

    var generatedAt: Date
    var currentCountry: String?
    var dayOfStay: Int
    var daysThisYearInCurrent: Int
    var year: Int
    var countriesThisYear: Int
    var travelDaysThisYear: Int
    var homeCountry: String?
    /// Every country visited this year with day counts, days descending —
    /// feeds the top list and (G2) the dot map.
    var countries: [CountryDays]
}

enum SharedSnapshotStore {
    static var appGroupID: String {
        "group." + (Bundle.main.bundleIdentifier ?? "")
    }

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("snapshot.json")
    }

    /// No-op until the user adds the App Groups capability (README §8) —
    /// containerURL is nil without it and the widget shows its placeholder.
    @MainActor
    static func write(from store: LedgerStore) {
        guard let url = fileURL else { return }

        let today = store.todayEpoch
        let (year, _, _) = EpochDay(value: today).civil()
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let stats = store.stats(in: jan1...today)
        let stay = store.currentStay()

        let snapshot = SharedSnapshot(
            generatedAt: Date(),
            currentCountry: stay?.countryCode,
            dayOfStay: stay?.days ?? 0,
            daysThisYearInCurrent: stay.map { store.daysThisYear(in: $0.countryCode) } ?? 0,
            year: year,
            countriesThisYear: stats.countriesVisited,
            travelDaysThisYear: stats.travelDays,
            homeCountry: store.homeCountry,
            countries: stats.daysPerCountry
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                .map { SharedSnapshot.CountryDays(code: $0.key, days: $0.value) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
