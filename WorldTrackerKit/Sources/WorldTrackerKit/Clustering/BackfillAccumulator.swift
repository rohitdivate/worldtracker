import Foundation

/// One (day, country) aggregate produced by the photo backfill.
public struct BackfillDayFact: Sendable, Equatable {
    public let epochDay: Int
    public let countryCode: String
    public var photoCount: Int
    public var firstSeen: Date
    public var lastSeen: Date

    public init(epochDay: Int, countryCode: String, photoCount: Int, firstSeen: Date, lastSeen: Date) {
        self.epochDay = epochDay
        self.countryCode = countryCode
        self.photoCount = photoCount
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}

/// One (day, ~1km cell) evidence aggregate — the map/evidence row.
public struct BackfillCellEvidence: Sendable, Equatable {
    public let epochDay: Int
    public let cellLatitude: Double
    public let cellLongitude: Double
    public var photoCount: Int
    public let representativeAssetID: String?
    public let countryCode: String?
    public let city: String?
    public let timeZoneID: String?

    public init(
        epochDay: Int,
        cellLatitude: Double,
        cellLongitude: Double,
        photoCount: Int,
        representativeAssetID: String?,
        countryCode: String?,
        city: String?,
        timeZoneID: String?
    ) {
        self.epochDay = epochDay
        self.cellLatitude = cellLatitude
        self.cellLongitude = cellLongitude
        self.photoCount = photoCount
        self.representativeAssetID = representativeAssetID
        self.countryCode = countryCode
        self.city = city
        self.timeZoneID = timeZoneID
    }
}

/// The pure aggregation core of the photo backfill: timezone-correct day
/// bucketing, (day, country) fact aggregation, and (day, cell) evidence
/// dedupe. The engine feeds it geocoded photos and drains it per chunk;
/// the persistent upsert applies `merge`, so summing per-chunk flushes is
/// exactly equivalent to one accumulator that never flushed.
public struct BackfillAccumulator: Sendable {
    private var dayFacts: [String: BackfillDayFact] = [:]
    private var cells: [String: BackfillCellEvidence] = [:]
    private var countrySet: Set<String> = []
    /// Countries in first-seen order — survives flushes; drives the flag
    /// stream and the checkpoint's flagsCSV.
    public private(set) var countriesInOrder: [String] = []
    /// Distinct epoch days seen across the whole scan (survives flushes).
    public private(set) var uniqueDays: Set<Int> = []

    public init() {}

    /// ~110m dedupe key that keeps offline geocoding cost trivial.
    public static func geoCacheKey(latitude: Double, longitude: Double) -> Int64 {
        Int64((latitude + 90) * 1000) &* 400_000 &+ Int64((longitude + 180) * 1000)
    }

    /// 2-decimal cell rounding (≈ 1.1 km).
    public static func cellValue(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// Feed one geocoded photo. Returns true when `countryCode` is being
    /// seen for the first time in this scan (drives the flag cascade).
    @discardableResult
    public mutating func add(
        assetID: String,
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        countryCode: String,
        city: String?,
        timeZoneID: String?
    ) -> Bool {
        let tz = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone(identifier: "UTC")!
        let day = EpochDay(date: timestamp, timeZone: tz).value
        uniqueDays.insert(day)

        let factKey = "\(day)|\(countryCode)"
        if var fact = dayFacts[factKey] {
            fact.photoCount += 1
            fact.firstSeen = min(fact.firstSeen, timestamp)
            fact.lastSeen = max(fact.lastSeen, timestamp)
            dayFacts[factKey] = fact
        } else {
            dayFacts[factKey] = BackfillDayFact(
                epochDay: day, countryCode: countryCode,
                photoCount: 1, firstSeen: timestamp, lastSeen: timestamp
            )
        }

        let cellLat = Self.cellValue(latitude)
        let cellLon = Self.cellValue(longitude)
        let cellKey = "\(day)|\(cellLat)|\(cellLon)"
        if var cell = cells[cellKey] {
            cell.photoCount += 1
            cells[cellKey] = cell
        } else {
            cells[cellKey] = BackfillCellEvidence(
                epochDay: day, cellLatitude: cellLat, cellLongitude: cellLon,
                photoCount: 1, representativeAssetID: assetID,
                countryCode: countryCode, city: city, timeZoneID: timeZoneID
            )
        }

        if countrySet.insert(countryCode).inserted {
            countriesInOrder.append(countryCode)
            return true
        }
        return false
    }

    /// Drain the current chunk's aggregates. Country and unique-day tracking
    /// persist across flushes.
    public mutating func flush() -> (dayFacts: [BackfillDayFact], evidence: [BackfillCellEvidence]) {
        defer {
            dayFacts = [:]
            cells = [:]
        }
        return (Array(dayFacts.values), Array(cells.values))
    }

    /// The merge rule the persistent upsert applies when a later chunk hits a
    /// (day, country) an earlier chunk already wrote.
    public static func merge(into existing: inout BackfillDayFact, _ incoming: BackfillDayFact) {
        existing.photoCount += incoming.photoCount
        existing.firstSeen = min(existing.firstSeen, incoming.firstSeen)
        existing.lastSeen = max(existing.lastSeen, incoming.lastSeen)
    }

    /// Evidence merge rule: counts add; identity fields keep the first row's.
    public static func merge(into existing: inout BackfillCellEvidence, _ incoming: BackfillCellEvidence) {
        existing.photoCount += incoming.photoCount
    }
}

/// Chunk-boundary math for the resumable scan.
public enum BackfillChunker {
    /// Exclusive end index for a chunk starting at `start` targeting `target`
    /// items, extended so a run of equal timestamps never straddles the
    /// boundary. That invariant makes the resume predicate
    /// `creationDate > cursor` exact with no tiebreak field.
    public static func chunkEnd(
        start: Int,
        target: Int,
        count: Int,
        timestamp: (Int) -> Date?
    ) -> Int {
        var end = min(start + max(target, 1), count)
        while end > start, end < count,
              let last = timestamp(end - 1), let next = timestamp(end),
              last == next {
            end += 1
        }
        return end
    }
}
