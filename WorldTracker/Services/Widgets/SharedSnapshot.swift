import Foundation
import Photos
import SwiftData
import UIKit
import WidgetKit
import WorldTrackerKit

/// The app→widget bridge: one small JSON in the App Group container,
/// rewritten on every ledger change, plus an exported On-This-Day photo.
/// BeenThereWidgets/WidgetSnapshot.swift mirrors this Codable shape — keep
/// the two in sync (the validator enforces field parity).
struct SharedSnapshot: Codable {
    struct CountryDays: Codable {
        let code: String
        let days: Int
    }

    struct OnThisDayEntry: Codable {
        let yearsAgo: Int
        let countryCode: String?
        let city: String?
        let hasPhoto: Bool
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
    /// feeds the top list and the dot map.
    var countries: [CountryDays]
    /// Jan 1 → today, true = away from that day's home (optional: older
    /// snapshots decode without it).
    var travelDayFlags: [Bool]?
    /// Where you were on this date 1…10 years ago, oldest data wins a photo.
    var onThisDay: [OnThisDayEntry]?
    /// Epoch day the most recent never-seen-before country entered the log.
    var lastNewCountryDay: Int?
    /// Lifetime distinct countries (the %-of-world milestone basis).
    var allTimeCountries: Int?
}

enum SharedSnapshotStore {
    static var appGroupID: String {
        "group." + (Bundle.main.bundleIdentifier ?? "")
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// True once the App Groups capability is live in this build's signing.
    static var hasAppGroup: Bool { containerURL != nil }

    /// When the snapshot last landed on disk (Settings diagnostics row).
    static var lastWrite: Date? {
        UserDefaults.standard.object(forKey: "lastSnapshotWrite") as? Date
    }

    /// The Live Activity needs no App Group, so it syncs regardless; the
    /// widget file is a no-op until the capability exists (README §8).
    @MainActor
    static func write(from store: LedgerStore) {
        TravelLiveActivityManager.sync(store: store)
        guard let container = containerURL else { return }
        let url = container.appendingPathComponent("snapshot.json")

        let today = store.todayEpoch
        let (year, _, _) = EpochDay(value: today).civil()
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let stats = store.stats(in: jan1...today)
        let stay = store.currentStay()

        let travelDayFlags = store.resolvedDays(in: jan1...today).map {
            !$0.countryCodes.isEmpty
                && $0.countryCodes != [store.homeOn($0.day)].compactMap({ $0 })
        }

        let memories = onThisDayEntries(store: store, today: today)
        let momentum = momentumFacts(store: store, today: today)

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
                .map { SharedSnapshot.CountryDays(code: $0.key, days: $0.value) },
            travelDayFlags: travelDayFlags,
            onThisDay: memories.map(\.entry),
            lastNewCountryDay: momentum.lastNewDay,
            allTimeCountries: momentum.allTimeCountries
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        UserDefaults.standard.set(Date(), forKey: "lastSnapshotWrite")
        WidgetCenter.shared.reloadAllTimelines()

        exportMemoryPhoto(memories, container: container)
    }

    // MARK: - On This Day

    private struct Memory {
        let entry: SharedSnapshot.OnThisDayEntry
        let assetID: String?
        let isAway: Bool
        let photoCount: Int
    }

    @MainActor
    private static func onThisDayEntries(store: LedgerStore, today: Int) -> [Memory] {
        let (year, month, dayOfMonth) = EpochDay(value: today).civil()
        let context = AppContainer.shared.modelContainer.mainContext
        var memories: [Memory] = []

        for yearsAgo in 1...10 {
            let target = EpochDay.daysFromCivil(year: year - yearsAgo, month: month, day: dayOfMonth)
            let resolved = store.day(target)
            guard !resolved.countryCodes.isEmpty else { continue }

            let predicate = #Predicate<PhotoEvidence> { $0.epochDay == target }
            let rows = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
            let best = rows.max { $0.photoCount < $1.photoCount }

            let countryCode = resolved.countryCodes.first
            memories.append(
                Memory(
                    entry: SharedSnapshot.OnThisDayEntry(
                        yearsAgo: yearsAgo,
                        countryCode: countryCode,
                        city: best?.city,
                        hasPhoto: best?.representativeAssetID != nil
                    ),
                    assetID: best?.representativeAssetID,
                    isAway: countryCode != store.homeOn(target),
                    photoCount: best?.photoCount ?? 0
                )
            )
        }
        return memories
    }

    /// Export the best memory's photo for the widget: away days beat home
    /// days, more photos beat fewer. Local-only; no photo → file removed.
    private static func exportMemoryPhoto(_ memories: [Memory], container: URL) {
        let fileURL = container.appendingPathComponent("onthisday.jpg")
        let best = memories
            .filter { $0.assetID != nil }
            .max { ($0.isAway ? 1 : 0, $0.photoCount) < ($1.isAway ? 1 : 0, $1.photoCount) }

        guard let assetID = best?.assetID else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = fetch.firstObject else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 800, height: 800),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let data = image?.jpegData(compressionQuality: 0.8) else { return }
            try? data.write(to: fileURL, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Momentum

    /// Lifetime distinct countries + the most recent day a never-seen-before
    /// country entered the log — one pass over the (cached) resolved days.
    @MainActor
    private static func momentumFacts(
        store: LedgerStore, today: Int
    ) -> (lastNewDay: Int?, allTimeCountries: Int) {
        let earliest = min(store.earliestDay ?? today, today)
        var seen: Set<String> = []
        var lastFirst: Int?
        for day in store.resolvedDays(in: earliest...today) {
            for code in day.countryCodes where !seen.contains(code) {
                seen.insert(code)
                lastFirst = day.day
            }
        }
        return (lastFirst, seen.count)
    }
}
