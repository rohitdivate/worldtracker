import Foundation
import UIKit

/// Mirror of the app's SharedSnapshot
/// (WorldTracker/Services/Widgets/SharedSnapshot.swift) — keep in sync.
/// The widget only ever READS; the app owns the file.
struct WidgetSnapshot: Codable {
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
    var countries: [CountryDays]
    var travelDayFlags: [Bool]?
    var onThisDay: [OnThisDayEntry]?
    var lastNewCountryDay: Int?
    var allTimeCountries: Int?
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
        ],
        travelDayFlags: (0..<200).map { (20..<29).contains($0) || (60..<74).contains($0) || (150..<161).contains($0) },
        onThisDay: [
            .init(yearsAgo: 2, countryCode: "JP", city: "Kyoto", hasPhoto: false),
            .init(yearsAgo: 5, countryCode: "IT", city: "Rome", hasPhoto: false),
        ],
        lastNewCountryDay: nil,
        allTimeCountries: 14
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

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// False = the App Groups capability isn't in this target's signing —
    /// the one failure the widget itself can diagnose.
    static var hasAppGroup: Bool { containerURL != nil }

    static func load() -> WidgetSnapshot? {
        guard
            let url = containerURL?.appendingPathComponent("snapshot.json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// The On This Day photo exported by the app, if present.
    static func onThisDayImage() -> UIImage? {
        guard let url = containerURL?.appendingPathComponent("onthisday.jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

/// Honest empty-state copy: a missing App Group and a not-yet-written
/// snapshot are different problems with different fixes.
var widgetEmptyMessage: String {
    WidgetSnapshotReader.hasAppGroup
        ? "Open Been There once to light this up"
        : "Finish widget setup in Xcode — README §8 (App Groups)"
}

func widgetCountryName(_ code: String) -> String {
    Locale.current.localizedString(forRegionCode: code) ?? code
}

// MARK: - Shared provider

import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// One provider for every snapshot-driven widget: entry now, refresh just
/// after midnight (day counters roll); the app pushes reloads for the rest.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview
            ? .sample
            : (WidgetSnapshotReader.load() ?? .sample)
        completion(SnapshotEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: WidgetSnapshotReader.load())
        let nextMidnight = Calendar.current
            .startOfDay(for: Date())
            .addingTimeInterval(24 * 60 * 60 + 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}
