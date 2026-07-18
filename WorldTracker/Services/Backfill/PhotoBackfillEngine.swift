import Foundation
import Observation
import Photos
import SwiftData
import WorldTrackerKit

/// Observable progress for the Time Machine UI.
@MainActor
@Observable
final class BackfillProgress {
    enum Stage: Equatable {
        case idle
        case requestingAuth
        case scanning
        case writing
        case done(days: Int, photos: Int)
        case failed(String)
    }

    var stage: Stage = .idle
    var fraction: Double = 0
    var processed = 0
    var total = 0
    var foundDays = 0
    var countriesFound: Set<String> = []
    /// Rolling stream of recently-found flags for the develop animation.
    var recentFlags: [String] = []

    var isRunning: Bool {
        switch stage {
        case .requestingAuth, .scanning, .writing: return true
        default: return false
        }
    }
}

/// Database writer for the backfill (off-main).
@ModelActor
actor BackfillWriter {
    /// Re-sync contract: photo-derived rows are replaced; manual edits and
    /// GPS facts are never touched.
    func clearPhotoData() {
        let photoRaw = FactSource.photo.rawValue
        try? modelContext.delete(
            model: CountryDayFact.self,
            where: #Predicate { $0.sourceRaw == photoRaw }
        )
        try? modelContext.delete(model: PhotoEvidence.self)
        try? modelContext.save()
    }

    func write(
        dayFacts: [(day: Int, country: String, count: Int, first: Date, last: Date)],
        evidence: [(day: Int, lat: Double, lon: Double, count: Int, rep: String?, country: String?, city: String?, tz: String?)]
    ) {
        let photoRaw = FactSource.photo.rawValue
        for fact in dayFacts {
            let day = fact.day
            let country = fact.country
            let predicate = #Predicate<CountryDayFact> {
                $0.epochDay == day && $0.countryCode == country && $0.sourceRaw == photoRaw
            }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.evidenceCount += fact.count
                existing.lastSeenAt = max(existing.lastSeenAt ?? fact.last, fact.last)
                existing.firstSeenAt = min(existing.firstSeenAt ?? fact.first, fact.first)
            } else {
                let row = CountryDayFact(
                    epochDay: day,
                    countryCode: country,
                    sourceRaw: photoRaw,
                    confidence: 0.9,
                    seenAt: fact.first
                )
                row.evidenceCount = fact.count
                row.lastSeenAt = fact.last
                modelContext.insert(row)
            }
        }
        for item in evidence {
            modelContext.insert(
                PhotoEvidence(
                    epochDay: item.day,
                    latitude: item.lat,
                    longitude: item.lon,
                    photoCount: item.count,
                    representativeAssetID: item.rep,
                    countryCode: item.country,
                    city: item.city,
                    timeZoneID: item.tz
                )
            )
        }
        try? modelContext.save()
    }

    func updateCheckpoint(status: String, processed: Int, total: Int, days: Int) {
        var descriptor = FetchDescriptor<BackfillCheckpoint>()
        descriptor.fetchLimit = 1
        let checkpoint = (try? modelContext.fetch(descriptor))?.first ?? {
            let fresh = BackfillCheckpoint()
            modelContext.insert(fresh)
            return fresh
        }()
        checkpoint.statusRaw = status
        checkpoint.processedCount = processed
        checkpoint.totalCount = total
        checkpoint.reconstructedDays = days
        checkpoint.updatedAt = Date()
        try? modelContext.save()
    }

    func lastCheckpoint() -> (status: String, days: Int, photos: Int, at: Date)? {
        var descriptor = FetchDescriptor<BackfillCheckpoint>()
        descriptor.fetchLimit = 1
        guard let checkpoint = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return (checkpoint.statusRaw, checkpoint.reconstructedDays, checkpoint.processedCount, checkpoint.updatedAt)
    }
}

/// The Time Machine: reads ONLY metadata (coordinate + timestamp) from the
/// photo library — never pixels, never iCloud downloads — geocodes offline,
/// and rebuilds years of travel history in about a minute.
final class PhotoBackfillEngine {
    private let writer: BackfillWriter
    private let geoProvider: GeoLookupProvider
    let progress: BackfillProgress

    @MainActor
    init(container: ModelContainer, geoProvider: GeoLookupProvider) {
        self.writer = BackfillWriter(modelContainer: container)
        self.geoProvider = geoProvider
        self.progress = BackfillProgress()
    }

    /// Kick off a full (re-)scan. Safe to call repeatedly; photo-derived data
    /// is replaced, manual and GPS data are preserved.
    @MainActor
    func run() {
        guard !progress.isRunning else { return }
        progress.stage = .requestingAuth
        progress.fraction = 0
        progress.processed = 0
        progress.foundDays = 0
        progress.countriesFound = []
        progress.recentFlags = []

        Task.detached(priority: .userInitiated) { [self] in
            await self.execute()
        }
    }

    private func execute() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                progress.stage = .failed("Photo access was not granted. You can enable it in iOS Settings → Privacy → Photos.")
            }
            return
        }

        guard let lookup = try? await geoProvider.lookup() else {
            await MainActor.run { progress.stage = .failed("The offline atlas failed to load.") }
            return
        }

        await MainActor.run { progress.stage = .scanning }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        let total = result.count
        await MainActor.run { progress.total = total }

        await writer.updateCheckpoint(status: "running", processed: 0, total: total, days: 0)
        await writer.clearPhotoData()

        // day+country → aggregate; day+cell → evidence aggregate
        var dayCountry: [String: (day: Int, country: String, count: Int, first: Date, last: Date)] = [:]
        var cellEvidence: [String: (day: Int, lat: Double, lon: Double, count: Int, rep: String?, country: String?, city: String?, tz: String?)] = [:]
        var geoCache: [Int64: GeoResolution] = [:]
        var flagsSeen: Set<String> = []
        var processed = 0

        result.enumerateObjects { asset, _, _ in
            processed += 1
            defer {
                if processed % 800 == 0 || processed == total {
                    let done = processed
                    let days = dayCountry.count
                    let countries = flagsSeen
                    Task { @MainActor [self] in
                        self.progress.processed = done
                        self.progress.fraction = total > 0 ? Double(done) / Double(total) : 1
                        self.progress.foundDays = days
                        self.progress.countriesFound = countries
                    }
                }
            }

            guard let location = asset.location,
                  let created = asset.creationDate else { return }
            if asset.mediaSubtypes.contains(.photoScreenshot) { return }

            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            guard abs(lat) <= 90, abs(lon) <= 180, !(lat == 0 && lon == 0) else { return }

            // ~110m dedupe key keeps offline geocoding cost trivial.
            let cacheKey = Int64((lat + 90) * 1000) &* 400_000 &+ Int64((lon + 180) * 1000)
            let res: GeoResolution
            if let cached = geoCache[cacheKey] {
                res = cached
            } else {
                res = lookup.resolve(GeoPoint(latitude: lat, longitude: lon))
                geoCache[cacheKey] = res
            }
            guard let country = res.countryCode else { return }

            let tz = res.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone(identifier: "UTC")!
            let day = EpochDay(date: created, timeZone: tz).value

            let dcKey = "\(day)|\(country)"
            if var existing = dayCountry[dcKey] {
                existing.count += 1
                existing.first = min(existing.first, created)
                existing.last = max(existing.last, created)
                dayCountry[dcKey] = existing
            } else {
                dayCountry[dcKey] = (day, country, 1, created, created)
                if !flagsSeen.contains(country) || dayCountry.count % 25 == 0 {
                    flagsSeen.insert(country)
                    let flag = flagEmoji(country)
                    Task { @MainActor [self] in
                        self.progress.recentFlags.append(flag)
                        if self.progress.recentFlags.count > 18 {
                            self.progress.recentFlags.removeFirst()
                        }
                    }
                }
            }

            let cellLat = (lat * 100).rounded() / 100
            let cellLon = (lon * 100).rounded() / 100
            let ceKey = "\(day)|\(cellLat)|\(cellLon)"
            if var existing = cellEvidence[ceKey] {
                existing.count += 1
                cellEvidence[ceKey] = existing
            } else {
                cellEvidence[ceKey] = (
                    day, cellLat, cellLon, 1, asset.localIdentifier,
                    country, res.cityName, res.timeZoneID
                )
            }
        }

        await MainActor.run { progress.stage = .writing }
        await writer.write(dayFacts: Array(dayCountry.values), evidence: Array(cellEvidence.values))

        let uniqueDays = Set(dayCountry.values.map(\.day)).count
        await writer.updateCheckpoint(status: "done", processed: processed, total: total, days: uniqueDays)

        await MainActor.run {
            progress.stage = .done(days: uniqueDays, photos: processed)
            progress.fraction = 1
            NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
        }
    }

    func lastSync() async -> (status: String, days: Int, photos: Int, at: Date)? {
        await writer.lastCheckpoint()
    }
}
