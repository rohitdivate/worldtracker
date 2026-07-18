import Foundation
import Photos
import SwiftData
import SwiftUI
import WorldTrackerKit

/// Assembles everything a Wrapped presentation needs, render-ready:
/// stats (Kit), map geometry, photo moments with preloaded local thumbnails.
@MainActor
final class YearInReviewBuilder {
    struct PhotoMoment: Identifiable, Hashable {
        let id: UUID
        let epochDay: Int
        let city: String?
        let countryCode: String?
        let assetID: String
        let photoCount: Int
    }

    struct WrappedData {
        let stats: YearInReviewStats
        let isPartialYear: Bool
        let homeCentroid: GeoPoint?
        /// firstAppearanceOrder minus home, with map centroids.
        let arcTargets: [(code: String, center: GeoPoint)]
        let photoMoments: [PhotoMoment]
        /// Preloaded, strictly-local thumbnails keyed by asset id.
        let thumbnails: [String: UIImage]
        let shapes: WorldMapShapes?
        /// Full year tally (not just top-5) — drives map fill intensity.
        let daysPerCountry: [String: Int]
        /// One flag per day from Jan 1, true = away from home — the dot grid
        /// lights the actual calendar days, not a synthetic prefix.
        let travelDayFlags: [Bool]
    }

    private let store: LedgerStore
    private let container: ModelContainer
    private let placesEngine: PlacesEngine
    private var cachedShapes: WorldMapShapes?

    init(store: LedgerStore, container: ModelContainer, placesEngine: PlacesEngine) {
        self.store = store
        self.container = container
        self.placesEngine = placesEngine
    }

    /// Years with enough data for a story, newest first.
    func availableYears() -> [Int] {
        let today = store.todayEpoch
        let (currentYear, _, _) = EpochDay(value: today).civil()
        guard let earliest = store.earliestDay else { return [] }
        let (firstYear, _, _) = EpochDay(value: earliest).civil()

        return (firstYear...currentYear).reversed().filter { year in
            quickStats(year: year).meetsMinimumData
        }
    }

    func build(year: Int) async -> WrappedData? {
        let stats = await fullStats(year: year)
        guard stats.meetsMinimumData else { return nil }

        let today = store.todayEpoch
        let (currentYear, _, _) = EpochDay(value: today).civil()

        if cachedShapes == nil {
            cachedShapes = try? await Task.detached { try WorldMapShapes() }.value
        }
        let shapes = cachedShapes

        let home = stats.homeCountry
        let homeCentroid = home.flatMap { shapes?.centroid(forCountry: $0) }
        let arcTargets: [(String, GeoPoint)] = stats.firstAppearanceOrder
            .filter { $0 != home }
            .prefix(14)
            .compactMap { code in
                shapes?.centroid(forCountry: code).map { (code, $0) }
            }

        let moments = photoMoments(year: year, home: home)
        let thumbnails = await loadThumbnails(for: moments.map(\.assetID))

        let range = yearRange(year)
        let homeCodes = [home].compactMap { $0 }
        let travelDayFlags = store.resolvedDays(in: range).map {
            !$0.countryCodes.isEmpty && $0.countryCodes != homeCodes
        }

        return WrappedData(
            stats: stats,
            isPartialYear: year == currentYear,
            homeCentroid: homeCentroid,
            arcTargets: arcTargets,
            photoMoments: moments,
            thumbnails: thumbnails,
            shapes: shapes,
            daysPerCountry: store.stats(in: range).daysPerCountry,
            travelDayFlags: travelDayFlags
        )
    }

    // MARK: - Stats assembly

    private func yearRange(_ year: Int) -> ClosedRange<Int> {
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let dec31 = EpochDay.daysFromCivil(year: year, month: 12, day: 31)
        return jan1...min(dec31, store.todayEpoch)
    }

    private func quickStats(year: Int) -> YearInReviewStats {
        let range = yearRange(year)
        guard range.lowerBound <= range.upperBound else {
            return YearInReview.compute(year: year, days: [], homeCountry: nil, priorCountryCodes: [])
        }
        return YearInReview.compute(
            year: year,
            days: store.resolvedDays(in: range),
            homeCountry: store.homeCountry,
            priorCountryCodes: priorCountries(before: range.lowerBound)
        )
    }

    private func fullStats(year: Int) async -> YearInReviewStats {
        let range = yearRange(year)
        guard range.lowerBound <= range.upperBound else {
            return YearInReview.compute(year: year, days: [], homeCountry: nil, priorCountryCodes: [])
        }
        return YearInReview.compute(
            year: year,
            days: store.resolvedDays(in: range),
            homeCountry: store.homeCountry,
            priorCountryCodes: priorCountries(before: range.lowerBound),
            places: await placeInputs()
        )
    }

    private func priorCountries(before day: Int) -> Set<String> {
        guard let earliest = store.earliestDay, earliest < day else { return [] }
        return Set(store.stats(in: earliest...(day - 1)).daysPerCountry.keys)
    }

    private func placeInputs() async -> [PlaceVisitInput] {
        // Snapshot-based; place volume is small (hundreds at most).
        let places = await placesEngine.allPlaces()
        var collected: [PlaceVisitInput] = []
        for place in places.prefix(300) {
            let visits = await placesEngine.visits(for: place.id)
            collected.append(
                PlaceVisitInput(
                    name: place.name,
                    city: place.city,
                    countryCode: place.countryCode,
                    visitEpochDays: visits.map(\.epochDay)
                )
            )
        }
        return collected
    }

    // MARK: - Photos

    private func photoMoments(year: Int, home: String?) -> [PhotoMoment] {
        let range = yearRange(year)
        let lower = range.lowerBound
        let upper = range.upperBound
        let predicate = #Predicate<PhotoEvidence> {
            $0.epochDay >= lower && $0.epochDay <= upper
        }
        let rows = (try? container.mainContext.fetch(FetchDescriptor(predicate: predicate))) ?? []

        // Prefer away-from-home, then photo volume; one moment per day.
        var byDay: [Int: PhotoEvidence] = [:]
        for row in rows {
            if let existing = byDay[row.epochDay] {
                let rowAway = row.countryCode != home
                let existingAway = existing.countryCode != home
                if (rowAway && !existingAway)
                    || (rowAway == existingAway && row.photoCount > existing.photoCount) {
                    byDay[row.epochDay] = row
                }
            } else {
                byDay[row.epochDay] = row
            }
        }
        return byDay.values
            .sorted {
                (($0.countryCode != home) ? 1 : 0, $0.photoCount)
                    > (($1.countryCode != home) ? 1 : 0, $1.photoCount)
            }
            .prefix(9)
            .compactMap { row in
                guard let assetID = row.representativeAssetID else { return nil }
                return PhotoMoment(
                    id: row.id,
                    epochDay: row.epochDay,
                    city: row.city,
                    countryCode: row.countryCode,
                    assetID: assetID,
                    photoCount: row.photoCount
                )
            }
    }

    /// PlaceDetailView's proven local-only recipe, awaited so WrappedData
    /// arrives render-ready (required for ImageRenderer share cards).
    private func loadThumbnails(for assetIDs: [String]) async -> [String: UIImage] {
        guard !assetIDs.isEmpty else { return [:] }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        guard !assets.isEmpty else { return [:] }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        var out: [String: UIImage] = [:]
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for asset in assets {
                group.enter()
                manager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 480, height: 480),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image {
                        DispatchQueue.main.async {
                            out[asset.localIdentifier] = image
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                continuation.resume()
            }
        }
        return out
    }
}
