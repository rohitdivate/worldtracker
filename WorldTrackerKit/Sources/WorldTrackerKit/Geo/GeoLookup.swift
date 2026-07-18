import Foundation

/// The result of resolving a coordinate against the offline atlas.
public struct GeoResolution: Sendable, Equatable {
    /// ISO 3166-1 alpha-2, nil for open ocean / unknown.
    public let countryCode: String?
    public let cityName: String?
    public let admin1: String?
    public let timeZoneID: String?
    /// True when the country came from the nearest-land fallback
    /// (coastal GPS noise, beaches, ferries) rather than a polygon hit.
    public let usedNearestLandFallback: Bool
}

/// Facade over the bundled offline atlas: country polygons + city index +
/// timezone→country table. One instance is shared app-wide; lookups are
/// pure and thread-safe.
public final class GeoLookup: @unchecked Sendable {
    public let countries: CountryGeocoder
    public let cities: CityIndex
    private let tzToCountry: [String: String]

    /// Nearest-land fallback range (≈ how far offshore we still credit the
    /// adjacent country).
    public static let fallbackKm = 25.0
    /// How far away a city may be and still name the location.
    public static let cityNamingKm = 50.0

    public enum LoadError: Error {
        case missingResource(String)
    }

    public init(countriesData: Data, citiesData: Data, tzCountriesJSON: Data) throws {
        countries = try CountryGeocoder(data: countriesData)
        cities = try CityIndex(data: citiesData)
        tzToCountry =
            (try? JSONDecoder().decode([String: String].self, from: tzCountriesJSON)) ?? [:]
    }

    /// Load from the Kit's own resource bundle — the normal way to construct.
    public convenience init() throws {
        try self.init(bundle: Bundle.module)
    }

    /// Load from an explicit bundle (tests, previews).
    public convenience init(bundle: Bundle) throws {
        func data(_ name: String, _ ext: String) throws -> Data {
            // Several strategies: Linux corelibs-foundation and Apple
            // Foundation resolve bundled subdirectories differently.
            var candidates: [URL] = []
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "GeoData") {
                candidates.append(url)
            }
            if let url = bundle.url(forResource: "GeoData/\(name)", withExtension: ext) {
                candidates.append(url)
            }
            if let base = bundle.resourceURL {
                candidates.append(base.appendingPathComponent("GeoData/\(name).\(ext)"))
            }
            candidates.append(bundle.bundleURL.appendingPathComponent("GeoData/\(name).\(ext)"))
            for url in candidates where FileManager.default.fileExists(atPath: url.path) {
                return try Data(contentsOf: url, options: .mappedIfSafe)
            }
            throw LoadError.missingResource("GeoData/\(name).\(ext)")
        }
        try self.init(
            countriesData: try data("countries50m", "bin"),
            citiesData: try data("cities", "bin"),
            tzCountriesJSON: try data("tz_countries", "json")
        )
    }

    /// Full resolution: country (polygon, else nearest-land fallback),
    /// naming city, admin1 and the coordinate's own timezone.
    public func resolve(_ point: GeoPoint) -> GeoResolution {
        var code = countries.countryCode(at: point)
        var fallback = false
        let naming = cities.nearestCity(to: point, maxKm: Self.cityNamingKm)

        if code == nil {
            if let near = cities.nearestCity(to: point, maxKm: Self.fallbackKm) {
                code = near.countryCode
                fallback = true
            }
        }

        return GeoResolution(
            countryCode: code,
            cityName: naming?.name,
            admin1: naming?.admin1.isEmpty == true ? nil : naming?.admin1,
            timeZoneID: naming?.timeZoneID,
            usedNearestLandFallback: fallback
        )
    }

    /// Country-only fast path (used by the tracking ingest hot path).
    public func countryCode(at point: GeoPoint) -> String? {
        if let code = countries.countryCode(at: point) {
            return code
        }
        return cities.nearestCity(to: point, maxKm: Self.fallbackKm)?.countryCode
    }

    /// Country for a timezone identifier — the border-crossing hint used when
    /// the device timezone changes before any GPS fix arrives.
    public func countryCode(forTimeZoneID id: String) -> String? {
        tzToCountry[id]
    }

    /// The timezone at a coordinate (from the nearest city). Used to bucket
    /// samples/photos into the day of the PLACE, not the device.
    public func timeZone(at point: GeoPoint) -> TimeZone? {
        guard let hit = cities.nearestCity(to: point, maxKm: Self.cityNamingKm) else {
            return nil
        }
        return TimeZone(identifier: hit.timeZoneID)
    }
}

/// Flag emoji from an ISO 3166-1 alpha-2 code — no image assets needed.
public func flagEmoji(_ isoCode: String) -> String {
    let base: UInt32 = 127397
    var out = ""
    for scalar in isoCode.uppercased().unicodeScalars {
        guard let flagScalar = UnicodeScalar(base + scalar.value) else { continue }
        out.unicodeScalars.append(flagScalar)
    }
    return out
}
