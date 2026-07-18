import Foundation
import Observation
import os
import Photos
import SwiftData
import UIKit
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
        case done(days: Int, photos: Int, countries: Int)
        case denied
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

/// Everything the UI needs to know about the last scan, snapshotted off the
/// checkpoint row.
struct BackfillCheckpointSnapshot: Sendable {
    let status: String
    let processed: Int
    let total: Int
    let days: Int
    let countries: Int
    let flags: [String]
    let generation: Int
    let cursor: Date?
    let at: Date
}

/// Database writer for the backfill (off-main).
///
/// Crash-safety contract: each chunk's facts, evidence, cursor, and progress
/// commit in ONE save — a crash rolls back all of them together, so on
/// resume every asset is processed exactly once. Old-generation rows are
/// never touched until the final swap.
@ModelActor
actor BackfillWriter {
    private func fetchOrCreateCheckpoint() -> BackfillCheckpoint {
        var descriptor = FetchDescriptor<BackfillCheckpoint>()
        descriptor.fetchLimit = 1
        if let existing = (try? modelContext.fetch(descriptor))?.first { return existing }
        let fresh = BackfillCheckpoint()
        modelContext.insert(fresh)
        return fresh
    }

    func checkpointState() -> BackfillCheckpointSnapshot? {
        var descriptor = FetchDescriptor<BackfillCheckpoint>()
        descriptor.fetchLimit = 1
        guard let cp = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return BackfillCheckpointSnapshot(
            status: cp.statusRaw,
            processed: cp.processedCount,
            total: cp.totalCount,
            days: cp.reconstructedDays,
            countries: cp.countriesCount,
            flags: cp.flagsCSV.isEmpty ? [] : cp.flagsCSV.components(separatedBy: ","),
            generation: cp.generation,
            cursor: cp.cursorTimestamp,
            at: cp.updatedAt
        )
    }

    func beginScan(generation: Int, total: Int, resuming: Bool) {
        let cp = fetchOrCreateCheckpoint()
        cp.statusRaw = "running"
        cp.generation = generation
        if !resuming {
            cp.processedCount = 0
            cp.totalCount = total
            cp.reconstructedDays = 0
            cp.countriesCount = 0
            cp.flagsCSV = ""
            cp.cursorTimestamp = nil
        }
        cp.updatedAt = Date()
        try? modelContext.save()
    }

    /// Downgrade a live checkpoint to "paused" (background time expired, or a
    /// stale "running" found at launch). Idempotent.
    func markPaused() {
        let cp = fetchOrCreateCheckpoint()
        guard cp.statusRaw == "running" else { return }
        cp.statusRaw = "paused"
        cp.updatedAt = Date()
        try? modelContext.save()
    }

    /// Upsert one chunk + advance the cursor, atomically.
    func writeChunk(
        generation: Int,
        dayFacts: [BackfillDayFact],
        evidence: [BackfillCellEvidence],
        cursor: Date?,
        processed: Int,
        uniqueDays: Int,
        countries: [String]
    ) {
        let photoRaw = FactSource.photo.rawValue

        if !dayFacts.isEmpty {
            // One batch fetch of this generation's rows in the chunk's day
            // range replaces a fetch per fact.
            let dayLo = dayFacts.map(\.epochDay).min() ?? 0
            let dayHi = dayFacts.map(\.epochDay).max() ?? 0
            let predicate = #Predicate<CountryDayFact> {
                $0.sourceRaw == photoRaw && $0.scanGeneration == generation &&
                $0.epochDay >= dayLo && $0.epochDay <= dayHi
            }
            let existing = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
            var byKey: [String: CountryDayFact] = [:]
            for row in existing { byKey["\(row.epochDay)|\(row.countryCode)"] = row }

            for fact in dayFacts {
                if let row = byKey["\(fact.epochDay)|\(fact.countryCode)"] {
                    row.evidenceCount += fact.photoCount
                    row.firstSeenAt = min(row.firstSeenAt ?? fact.firstSeen, fact.firstSeen)
                    row.lastSeenAt = max(row.lastSeenAt ?? fact.lastSeen, fact.lastSeen)
                } else {
                    let row = CountryDayFact(
                        epochDay: fact.epochDay,
                        countryCode: fact.countryCode,
                        sourceRaw: photoRaw,
                        confidence: 0.9,
                        seenAt: fact.firstSeen
                    )
                    row.evidenceCount = fact.photoCount
                    row.lastSeenAt = fact.lastSeen
                    row.scanGeneration = generation
                    modelContext.insert(row)
                }
            }
        }

        if !evidence.isEmpty {
            let dayLo = evidence.map(\.epochDay).min() ?? 0
            let dayHi = evidence.map(\.epochDay).max() ?? 0
            let predicate = #Predicate<PhotoEvidence> {
                $0.scanGeneration == generation &&
                $0.epochDay >= dayLo && $0.epochDay <= dayHi
            }
            let existing = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
            var byKey: [String: PhotoEvidence] = [:]
            for row in existing { byKey["\(row.epochDay)|\(row.latitude)|\(row.longitude)"] = row }

            for cell in evidence {
                if let row = byKey["\(cell.epochDay)|\(cell.cellLatitude)|\(cell.cellLongitude)"] {
                    row.photoCount += cell.photoCount
                } else {
                    let row = PhotoEvidence(
                        epochDay: cell.epochDay,
                        latitude: cell.cellLatitude,
                        longitude: cell.cellLongitude,
                        photoCount: cell.photoCount,
                        representativeAssetID: cell.representativeAssetID,
                        countryCode: cell.countryCode,
                        city: cell.city,
                        timeZoneID: cell.timeZoneID
                    )
                    row.scanGeneration = generation
                    modelContext.insert(row)
                }
            }
        }

        // Progress numbers are advisory mid-scan (max keeps a resumed scan
        // from regressing); the swap recomputes final truth from the store.
        let cp = fetchOrCreateCheckpoint()
        if let cursor { cp.cursorTimestamp = cursor }
        cp.processedCount = processed
        cp.reconstructedDays = max(cp.reconstructedDays, uniqueDays)
        cp.countriesCount = max(cp.countriesCount, countries.count)
        var flags = cp.flagsCSV.isEmpty ? [] : cp.flagsCSV.components(separatedBy: ",")
        for code in countries where !flags.contains(code) { flags.append(code) }
        cp.flagsCSV = flags.prefix(24).joined(separator: ",")
        cp.updatedAt = Date()

        try? modelContext.save()
    }

    /// Retire every other generation, then compute the final numbers from
    /// what actually survived. Idempotent: recovery re-runs it verbatim.
    func performSwap(generation: Int) -> (days: Int, countries: Int, flags: [String]) {
        let cp = fetchOrCreateCheckpoint()
        // Durable marker BEFORE the deletes so a crash mid-swap is resumable.
        cp.statusRaw = "swapping"
        cp.generation = generation
        cp.updatedAt = Date()
        try? modelContext.save()

        let photoRaw = FactSource.photo.rawValue
        try? modelContext.delete(
            model: CountryDayFact.self,
            where: #Predicate { $0.sourceRaw == photoRaw && $0.scanGeneration != generation }
        )
        try? modelContext.delete(
            model: PhotoEvidence.self,
            where: #Predicate { $0.scanGeneration != generation }
        )

        let facts = (try? modelContext.fetch(FetchDescriptor<CountryDayFact>(
            predicate: #Predicate { $0.sourceRaw == photoRaw }
        ))) ?? []
        let days = Set(facts.map(\.epochDay)).count
        var countryOrder: [String] = []
        var seen: Set<String> = []
        for fact in facts.sorted(by: { ($0.firstSeenAt ?? .distantPast) < ($1.firstSeenAt ?? .distantPast) })
        where seen.insert(fact.countryCode).inserted {
            countryOrder.append(fact.countryCode)
        }

        cp.statusRaw = "done"
        cp.reconstructedDays = days
        cp.countriesCount = countryOrder.count
        cp.flagsCSV = countryOrder.prefix(24).joined(separator: ",")
        cp.updatedAt = Date()
        try? modelContext.save()

        return (days, countryOrder.count, Array(countryOrder.prefix(24)))
    }
}

/// The Time Machine: reads ONLY metadata (coordinate + timestamp) from the
/// photo library — never pixels, never iCloud downloads — geocodes offline,
/// and rebuilds years of travel history in about a minute.
///
/// Write strategy: generation swap. A new scan writes `generation G+1` rows
/// alongside the existing generation and deletes the old one only after the
/// scan completes — an interrupted scan never costs existing history. While
/// both generations coexist, doubled photo evidence merges to the same
/// per-country verdicts, so day resolution is unchanged mid-scan.
final class PhotoBackfillEngine {
    private let writer: BackfillWriter
    private let geoProvider: GeoLookupProvider
    private let places: PlacesEngine
    let progress: BackfillProgress

    /// Flipped by the background-task expiration handler; checked at every
    /// chunk boundary.
    private let cancelRequested = OSAllocatedUnfairLock(initialState: false)

    private static let chunkTarget = 2000

    @MainActor
    init(container: ModelContainer, geoProvider: GeoLookupProvider, places: PlacesEngine) {
        self.writer = BackfillWriter(modelContainer: container)
        self.geoProvider = geoProvider
        self.places = places
        self.progress = BackfillProgress()
    }

    /// Kick off a full (re-)scan. Safe to call repeatedly; photo-derived data
    /// is replaced, manual and GPS data are preserved.
    @MainActor
    func run() {
        start(resume: false)
    }

    /// Launch-time recovery — safe in a background location relaunch:
    /// finishes an interrupted swap (cheap, idempotent DB work) and
    /// downgrades a stale "running" checkpoint to "paused". Never scans.
    @MainActor
    func recoverIfNeeded() {
        guard !progress.isRunning else { return }
        Task.detached(priority: .utility) { [writer] in
            guard let cp = await writer.checkpointState() else { return }
            switch cp.status {
            case "swapping":
                _ = await writer.performSwap(generation: cp.generation)
                await MainActor.run {
                    NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
                }
            case "running":
                await writer.markPaused()
            default:
                break
            }
        }
    }

    /// Foreground auto-resume: a paused scan was user-initiated, so it
    /// continues without asking again.
    @MainActor
    func resumeIfPaused() {
        guard !progress.isRunning else { return }
        Task { [self] in
            guard let cp = await writer.checkpointState() else { return }
            switch cp.status {
            case "paused", "running":
                // "running" = stale checkpoint recoverIfNeeded hasn't
                // downgraded yet; the engine is idle, so it's resumable.
                await MainActor.run { start(resume: true) }
            case "swapping":
                _ = await writer.performSwap(generation: cp.generation)
                await MainActor.run {
                    NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
                }
            default:
                break
            }
        }
    }

    @MainActor
    private func start(resume: Bool) {
        guard !progress.isRunning else { return }
        progress.stage = .requestingAuth
        progress.fraction = 0
        progress.processed = 0
        progress.foundDays = 0
        progress.countriesFound = []
        progress.recentFlags = []
        cancelRequested.withLock { $0 = false }

        Task.detached(priority: .userInitiated) { [self] in
            await execute(resume: resume)
        }
    }

    private func execute(resume: Bool) async {
        // A few extra minutes of runtime when the user leaves mid-scan; on
        // expiry the chunk loop checkpoints "paused" and stops cleanly.
        let taskID = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "photo-backfill") { [cancelRequested] in
                cancelRequested.withLock { $0 = true }
            }
        }
        await scan(resume: resume)
        await MainActor.run {
            if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
        }
    }

    private func scan(resume: Bool) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            await MainActor.run { progress.stage = .denied }
            return
        }

        guard let lookup = try? await geoProvider.lookup() else {
            await MainActor.run { progress.stage = .failed("The offline atlas failed to load.") }
            return
        }

        let checkpoint = await writer.checkpointState()
        let resuming = resume
            && checkpoint?.cursorTimestamp != nil
            && (checkpoint?.status == "paused" || checkpoint?.status == "running")
        let generation = resuming ? (checkpoint?.generation ?? 1)
                                  : (checkpoint?.generation ?? 0) + 1

        await MainActor.run { progress.stage = .scanning }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if resuming, let cursor = checkpoint?.cursorTimestamp {
            // Exact resume: chunk boundaries never split a creationDate tie,
            // so strictly-after is lossless.
            options.predicate = NSPredicate(format: "creationDate > %@", cursor as NSDate)
        }
        let result = PHAsset.fetchAssets(with: .image, options: options)

        let processedBase = resuming ? (checkpoint?.processed ?? 0) : 0
        let daysBase = resuming ? (checkpoint?.days ?? 0) : 0
        let total = resuming ? max(checkpoint?.total ?? 0, processedBase + result.count)
                             : result.count

        await MainActor.run { [total, processedBase] in
            progress.total = total
            progress.processed = processedBase
        }
        if resuming, let flags = checkpoint?.flags, !flags.isEmpty {
            await MainActor.run {
                progress.countriesFound = Set(flags)
                progress.recentFlags = flags.suffix(18).map(flagEmoji)
            }
        }

        await writer.beginScan(generation: generation, total: total, resuming: resuming)

        var accumulator = BackfillAccumulator()
        var geoCache: [Int64: GeoResolution] = [:]
        var placeSamples: [PhotoSample] = []
        var processed = processedBase
        let count = result.count
        var index = 0

        while index < count {
            if cancelRequested.withLock({ $0 }) {
                await writer.markPaused()
                await MainActor.run { progress.stage = .idle }
                return
            }

            let end = BackfillChunker.chunkEnd(
                start: index, target: Self.chunkTarget, count: count
            ) { result.object(at: $0).creationDate }

            var cursor: Date?
            for i in index..<end {
                let asset = result.object(at: i)
                processed += 1
                if let created = asset.creationDate { cursor = created }

                defer {
                    if processed % 800 == 0 || processed == total {
                        let done = processed
                        let days = daysBase + accumulator.uniqueDays.count
                        let countries = accumulator.countriesInOrder
                        Task { @MainActor [self] in
                            progress.processed = done
                            progress.fraction = total > 0 ? min(1, Double(done) / Double(total)) : 1
                            progress.foundDays = days
                            progress.countriesFound.formUnion(countries)
                        }
                    }
                }

                guard let location = asset.location,
                      let created = asset.creationDate else { continue }
                if asset.mediaSubtypes.contains(.photoScreenshot) { continue }

                let lat = location.coordinate.latitude
                let lon = location.coordinate.longitude
                guard abs(lat) <= 90, abs(lon) <= 180, !(lat == 0 && lon == 0) else { continue }

                let cacheKey = BackfillAccumulator.geoCacheKey(latitude: lat, longitude: lon)
                let res: GeoResolution
                if let cached = geoCache[cacheKey] {
                    res = cached
                } else {
                    res = lookup.resolve(GeoPoint(latitude: lat, longitude: lon))
                    geoCache[cacheKey] = res
                }
                guard let country = res.countryCode else { continue }

                let isNewCountry = accumulator.add(
                    assetID: asset.localIdentifier,
                    latitude: lat, longitude: lon,
                    timestamp: created,
                    countryCode: country,
                    city: res.cityName,
                    timeZoneID: res.timeZoneID
                )
                placeSamples.append(
                    PhotoSample(
                        id: asset.localIdentifier,
                        point: GeoPoint(latitude: lat, longitude: lon),
                        timestamp: created
                    )
                )
                if isNewCountry {
                    let flag = flagEmoji(country)
                    Task { @MainActor [self] in
                        progress.recentFlags.append(flag)
                        if progress.recentFlags.count > 18 {
                            progress.recentFlags.removeFirst()
                        }
                    }
                }
            }

            let (facts, evidence) = accumulator.flush()
            await writer.writeChunk(
                generation: generation,
                dayFacts: facts,
                evidence: evidence,
                cursor: cursor,
                processed: processed,
                uniqueDays: daysBase + accumulator.uniqueDays.count,
                countries: accumulator.countriesInOrder
            )
            index = end
        }

        await MainActor.run { progress.stage = .writing }

        // Places from photo clusters (the market, the museum — from your
        // past). A resumed scan only holds post-resume samples, so rebuilding
        // would clobber the full set with a partial one — skip; the old
        // places stand, and a full re-sync rebuilds them.
        if !resuming {
            let clusters = clusterPhotoSamples(placeSamples)
            await places.createPhotoPlaces(clusters: clusters, lookup: lookup)
        }

        let summary = await writer.performSwap(generation: generation)
        let photosExamined = processed

        await MainActor.run {
            progress.stage = .done(
                days: summary.days, photos: photosExamined, countries: summary.countries
            )
            progress.fraction = 1
            NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
            if UIApplication.shared.applicationState != .active {
                NotificationScheduler.shared.notifyBackfillComplete(
                    days: summary.days, countries: summary.countries
                )
            }
        }
    }

    func lastSync() async -> BackfillCheckpointSnapshot? {
        await writer.checkpointState()
    }
}
