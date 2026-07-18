import Foundation

/// Mirror of the app's SharedSnapshot
/// (WorldTracker/Services/Widgets/SharedSnapshot.swift) — keep in sync.
/// The widget only ever READS; the app owns the file.
struct WidgetSnapshot: Codable {
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
    var countries: [CountryDays]
}

extension WidgetSnapshot {
    /// Gallery placeholder data.
    static let sample = WidgetSnapshot(
        generatedAt: Date(),
        currentCountry: "JP",
        dayOfStay: 4,
        daysThisYearInCurrent: 11,
        year: 2026,
        countriesThisYear: 7,
        travelDaysThisYear: 34,
        homeCountry: "GB",
        countries: [
            .init(code: "GB", days: 160),
            .init(code: "JP", days: 11),
            .init(code: "ES", days: 9),
            .init(code: "FR", days: 8),
            .init(code: "DK", days: 3),
        ]
    )
}

enum WidgetSnapshotReader {
    /// The widget's bundle id is the app's + ".widgets" — strip it to
    /// derive the shared group, so a bundle-id change needs no code edits.
    static var appGroupID: String {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let appID = bundleID.hasSuffix(".widgets")
            ? String(bundleID.dropLast(".widgets".count))
            : bundleID
        return "group." + appID
    }

    static func load() -> WidgetSnapshot? {
        guard
            let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("snapshot.json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}

func widgetCountryName(_ code: String) -> String {
    Locale.current.localizedString(forRegionCode: code) ?? code
}
