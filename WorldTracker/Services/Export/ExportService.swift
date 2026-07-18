import Foundation
import SwiftData
import WorldTrackerKit

/// Your data, out: CSV for spreadsheets, JSON for completeness.
/// Also the manual-backup story for the truly-local configuration.
@MainActor
final class ExportService {
    private let store: LedgerStore

    init(store: LedgerStore) {
        self.store = store
    }

    /// day-per-row CSV of resolved history.
    func exportCSV() -> URL? {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let days = store.resolvedDays(in: earliest...today)

        var csv = "date,countries,source,inferred\n"
        for day in days where !day.countryCodes.isEmpty {
            let (y, m, d) = EpochDay(value: day.day).civil()
            let date = String(format: "%04d-%02d-%02d", y, m, d)
            let countries = day.countryCodes.joined(separator: "|")
            let source = day.isFilled ? "gap-fill" : (day.source?.rawValue ?? "")
            csv += "\(date),\(countries),\(source),\(day.isFilled)\n"
        }
        return write(csv.data(using: .utf8) ?? Data(), name: "BeenThere-history.csv")
    }

    /// Full-fidelity JSON: every resolved day plus provenance.
    func exportJSON() -> URL? {
        struct DayRecord: Codable {
            let date: String
            let countries: [String]
            let source: String?
            let inferred: Bool
            let hasNote: Bool
        }

        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let days = store.resolvedDays(in: earliest...today)

        let records = days.compactMap { day -> DayRecord? in
            guard !day.countryCodes.isEmpty else { return nil }
            let (y, m, d) = EpochDay(value: day.day).civil()
            return DayRecord(
                date: String(format: "%04d-%02d-%02d", y, m, d),
                countries: day.countryCodes,
                source: day.isFilled ? "gap-fill" : day.source?.rawValue,
                inferred: day.isFilled,
                hasNote: day.hasNote
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return nil }
        return write(data, name: "BeenThere-history.json")
    }

    private func write(_ data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
