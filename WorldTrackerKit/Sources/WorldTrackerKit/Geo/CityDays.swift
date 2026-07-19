import Foundation

/// One evidence row placing the user in a city on a day — fed from photo
/// evidence (weight = photoCount) and place visits (weight = 1).
public struct CityObservation: Sendable {
    public let city: String?
    public let countryCode: String?
    public let epochDay: Int
    public let latitude: Double
    public let longitude: Double
    public let weight: Int

    public init(
        city: String?,
        countryCode: String?,
        epochDay: Int,
        latitude: Double,
        longitude: Double,
        weight: Int
    ) {
        self.city = city
        self.countryCode = countryCode
        self.epochDay = epochDay
        self.latitude = latitude
        self.longitude = longitude
        self.weight = weight
    }
}

/// A visited city with its distinct-day count and a pin coordinate.
public struct CityDays: Sendable, Equatable, Identifiable {
    public var id: String { key }
    /// "\(countryCode ?? "??")|\(folded name)" — stable across name variants.
    public let key: String
    /// Best display variant (the spelling with the most evidence behind it).
    public let name: String
    public let countryCode: String?
    /// DISTINCT epoch days with any evidence in this city.
    public let days: Int
    public let latitude: Double
    public let longitude: Double

    public init(
        key: String, name: String, countryCode: String?,
        days: Int, latitude: Double, longitude: Double
    ) {
        self.key = key
        self.name = name
        self.countryCode = countryCode
        self.days = days
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Pure per-city day aggregation for the globe's zoomed-in chips.
public enum CityDayAggregator {
    /// Group observations by (countryCode, case/diacritic-folded city name):
    /// "Zürich" and "Zurich" merge; "Springfield US" and "Springfield CA"
    /// stay apart. Nil/empty cities are dropped. The pin coordinate is the
    /// single highest-weight observation — the busiest ~1km cell is a spot
    /// the user actually stood, where a centroid could be dragged into the
    /// sea by one mistagged outlier (and breaks at the antimeridian).
    public static func aggregate(_ observations: [CityObservation]) -> [CityDays] {
        struct Bucket {
            var days: Set<Int> = []
            var nameWeights: [String: Int] = [:]
            var best: CityObservation?
        }

        var buckets: [String: Bucket] = [:]
        for observation in observations {
            guard let rawCity = observation.city else { continue }
            let trimmed = rawCity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let folded = trimmed.folding(
                options: [.diacriticInsensitive, .caseInsensitive], locale: nil
            )
            let key = "\(observation.countryCode ?? "??")|\(folded)"

            var bucket = buckets[key] ?? Bucket()
            bucket.days.insert(observation.epochDay)
            bucket.nameWeights[trimmed, default: 0] += observation.weight
            if isBetterRepresentative(observation, than: bucket.best) {
                bucket.best = observation
            }
            buckets[key] = bucket
        }

        return buckets.compactMap { key, bucket -> CityDays? in
            guard let best = bucket.best else { return nil }
            let name = bucket.nameWeights
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                .first?.key ?? ""
            return CityDays(
                key: key,
                name: name,
                countryCode: best.countryCode,
                days: bucket.days.count,
                latitude: best.latitude,
                longitude: best.longitude
            )
        }
        .sorted { ($0.days, $1.name) > ($1.days, $0.name) }
    }

    /// Deterministic "busiest cell" pick: weight, then epochDay, then coords.
    private static func isBetterRepresentative(
        _ candidate: CityObservation, than current: CityObservation?
    ) -> Bool {
        guard let current else { return true }
        if candidate.weight != current.weight { return candidate.weight > current.weight }
        if candidate.epochDay != current.epochDay { return candidate.epochDay > current.epochDay }
        if candidate.latitude != current.latitude { return candidate.latitude > current.latitude }
        return candidate.longitude > current.longitude
    }

    /// Top `limit` cities inside a lat/lon box around the camera center.
    /// Longitude wraps across ±180; `longitudeDelta >= 360` passes everything.
    public static func visible(
        _ cities: [CityDays],
        centerLatitude: Double,
        centerLongitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double,
        limit: Int
    ) -> [CityDays] {
        let halfLat = latitudeDelta / 2
        let halfLon = longitudeDelta / 2
        let passesAllLongitudes = longitudeDelta >= 360

        return Array(
            cities.lazy.filter { city in
                guard abs(city.latitude - centerLatitude) <= halfLat else { return false }
                if passesAllLongitudes { return true }
                let dLon = (city.longitude - centerLongitude)
                    .remainder(dividingBy: 360)
                return abs(dLon) <= halfLon
            }
            .prefix(limit)
        )
    }
}
