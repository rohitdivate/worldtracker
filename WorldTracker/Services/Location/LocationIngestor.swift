import Foundation
import SwiftData
import WorldTrackerKit

/// Writes location evidence into the database off the main thread.
/// All writes for tracking go through here so upsert rules live in one place.
@ModelActor
actor LocationIngestor {
    /// Resolve a raw location event, persist the sample, upsert the day fact.
    func ingest(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        timestamp: Date,
        kind: SampleKind,
        lookup: GeoLookup
    ) {
        let point = GeoPoint(latitude: latitude, longitude: longitude)
        let res = lookup.resolve(point)

        // Bucket into the day of the PLACE (falls back to device tz offshore).
        let tz = res.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current
        let day = EpochDay(date: timestamp, timeZone: tz).value

        let sample = LocationSample(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            kindRaw: kind.rawValue,
            countryCode: res.countryCode,
            city: res.cityName,
            timeZoneID: res.timeZoneID,
            epochDay: day
        )
        modelContext.insert(sample)

        if let code = res.countryCode {
            let source: FactSource = (kind == .visitArrive || kind == .visitDepart) ? .visit : .gps
            upsertFact(
                epochDay: day,
                countryCode: code,
                source: source,
                confidence: res.usedNearestLandFallback ? 0.7 : 1.0,
                seenAt: timestamp
            )
        }

        try? modelContext.save()
        pruneIfNeeded()
    }

    /// Device timezone changed with no GPS fact yet today — record a hint.
    func ingestTimezoneHint(timeZoneID: String, timestamp: Date, lookup: GeoLookup) {
        guard let code = lookup.countryCode(forTimeZoneID: timeZoneID) else { return }
        guard let tz = TimeZone(identifier: timeZoneID) else { return }
        let day = EpochDay(date: timestamp, timeZone: tz).value

        // Skip if stronger evidence already exists for today.
        let gps = FactSource.gps.rawValue
        let visit = FactSource.visit.rawValue
        let predicate = #Predicate<CountryDayFact> {
            $0.epochDay == day && ($0.sourceRaw == gps || $0.sourceRaw == visit)
        }
        let existing = (try? modelContext.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
        guard existing == 0 else { return }

        upsertFact(
            epochDay: day,
            countryCode: code,
            source: .timezoneHint,
            confidence: 0.5,
            seenAt: timestamp
        )
        try? modelContext.save()
    }

    private func upsertFact(
        epochDay: Int,
        countryCode: String,
        source: FactSource,
        confidence: Double,
        seenAt: Date
    ) {
        let sourceRaw = source.rawValue
        let predicate = #Predicate<CountryDayFact> {
            $0.epochDay == epochDay && $0.countryCode == countryCode && $0.sourceRaw == sourceRaw
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let fact = try? modelContext.fetch(descriptor).first {
            fact.evidenceCount += 1
            fact.lastSeenAt = max(fact.lastSeenAt ?? seenAt, seenAt)
            fact.firstSeenAt = min(fact.firstSeenAt ?? seenAt, seenAt)
            fact.confidence = max(fact.confidence, confidence)
        } else {
            modelContext.insert(
                CountryDayFact(
                    epochDay: epochDay,
                    countryCode: countryCode,
                    sourceRaw: sourceRaw,
                    confidence: confidence,
                    seenAt: seenAt
                )
            )
        }
    }

    /// Keep the audit trail bounded: beyond 180 days, cap samples per day.
    private var pruneCounter = 0
    private func pruneIfNeeded() {
        pruneCounter += 1
        guard pruneCounter % 50 == 0 else { return }
        let cutoff = Date().addingTimeInterval(-180 * 86_400)
        let predicate = #Predicate<LocationSample> { $0.timestamp < cutoff }
        let old = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        var perDay: [Int: Int] = [:]
        for sample in old.sorted(by: { $0.timestamp < $1.timestamp }) {
            perDay[sample.epochDay, default: 0] += 1
            if perDay[sample.epochDay, default: 0] > 8 {
                modelContext.delete(sample)
            }
        }
        try? modelContext.save()
    }

    // MARK: - Queries for the health screen / developer log

    func recentSamples(limit: Int) -> [SampleSnapshot] {
        var descriptor = FetchDescriptor<LocationSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let samples = (try? modelContext.fetch(descriptor)) ?? []
        return samples.map(SampleSnapshot.init)
    }

    func stats() -> IngestStats {
        let total = (try? modelContext.fetchCount(FetchDescriptor<LocationSample>())) ?? 0
        var latest = FetchDescriptor<LocationSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        latest.fetchLimit = 1
        let last = (try? modelContext.fetch(latest))?.first
        return IngestStats(
            totalSamples: total,
            lastEventDate: last?.timestamp,
            lastEventKind: last?.kindRaw,
            lastEventPlace: [last?.city, last?.countryCode]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }
}

/// Sendable snapshot of a LocationSample for UI use.
struct SampleSnapshot: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let kindRaw: String
    let countryCode: String?
    let city: String?

    init(_ sample: LocationSample) {
        id = sample.id
        timestamp = sample.timestamp
        latitude = sample.latitude
        longitude = sample.longitude
        kindRaw = sample.kindRaw
        countryCode = sample.countryCode
        city = sample.city
    }
}

struct IngestStats: Sendable {
    var totalSamples = 0
    var lastEventDate: Date?
    var lastEventKind: String?
    var lastEventPlace: String = ""
}
