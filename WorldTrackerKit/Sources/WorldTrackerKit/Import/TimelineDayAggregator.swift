import Foundation

/// Collapses a stream of Timeline samples/stays into (day, country)
/// aggregates — mirrors the photo backfill's approach: rounded-coordinate
/// geocode cache, day bucketing in the PLACE's timezone (embedded UTC offset
/// as fallback, e.g. desert points with no city within 50 km), open-ocean
/// points dropped.
public struct TimelineDayAggregator {
    private let lookup: GeoLookup
    private var geoCache: [Int64: GeoResolution] = [:]
    private var aggregate: [String: ImportDayFact] = [:]
    private var countries: Set<String> = []
    private var skippedNoCountry = 0

    public init(lookup: GeoLookup) {
        self.lookup = lookup
    }

    public mutating func add(_ sample: TimelineSample) {
        guard let (country, timeZone) = resolve(sample.point, fallbackOffset: sample.utcOffsetSeconds) else {
            skippedNoCountry += 1
            return
        }
        let day = EpochDay(date: sample.timestamp, timeZone: timeZone).value
        record(day: day, country: country, at: sample.timestamp)
    }

    public mutating func add(_ stay: TimelineStay) {
        guard let (country, timeZone) = resolve(stay.point, fallbackOffset: stay.utcOffsetSeconds) else {
            skippedNoCountry += 1
            return
        }
        let startDay = EpochDay(date: stay.start, timeZone: timeZone).value
        let endDay = EpochDay(date: max(stay.start, stay.end), timeZone: timeZone).value
        for day in startDay...endDay {
            record(day: day, country: country, at: stay.start)
        }
    }

    public func finish() -> (facts: [ImportDayFact], countries: Set<String>, skippedNoCountry: Int) {
        (Array(aggregate.values), countries, skippedNoCountry)
    }

    // MARK: - Internals

    private mutating func resolve(
        _ point: GeoPoint, fallbackOffset: Int?
    ) -> (String, TimeZone)? {
        let key = Int64((point.latitude + 90) * 1000) &* 400_000
            &+ Int64((point.longitude + 180) * 1000)
        let res: GeoResolution
        if let cached = geoCache[key] {
            res = cached
        } else {
            res = lookup.resolve(point)
            geoCache[key] = res
        }
        guard let country = res.countryCode else { return nil }

        let timeZone = res.timeZoneID.flatMap(TimeZone.init(identifier:))
            ?? fallbackOffset.flatMap { TimeZone(secondsFromGMT: $0) }
            ?? TimeZone(identifier: "UTC")!
        return (country, timeZone)
    }

    private mutating func record(day: Int, country: String, at instant: Date) {
        countries.insert(country)
        let key = "\(day)|\(country)"
        if let existing = aggregate[key] {
            aggregate[key] = ImportDayFact(
                day: day,
                countryCode: country,
                evidenceCount: existing.evidenceCount + 1,
                first: min(existing.first, instant),
                last: max(existing.last, instant)
            )
        } else {
            aggregate[key] = ImportDayFact(
                day: day, countryCode: country, evidenceCount: 1, first: instant, last: instant
            )
        }
    }
}
