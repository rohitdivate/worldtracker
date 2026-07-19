import Foundation

/// One flight, as parsed from a CSV export.
public struct FlightRecord: Sendable, Equatable {
    /// Local departure date from the CSV (already place-local — no tz math).
    public let departureDay: Int
    public let originIATA: String
    public let destinationIATA: String
    /// Best available instants (actual preferred over scheduled), if present.
    public let departure: Date?
    public let arrival: Date?

    public init(departureDay: Int, originIATA: String, destinationIATA: String, departure: Date?, arrival: Date?) {
        self.departureDay = departureDay
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.departure = departure
        self.arrival = arrival
    }
}

public enum FlightCSVFormat: Sendable, Equatable {
    case flighty
    case generic
}

public struct FlightCSVParser {
    /// Flighty exports have the gate/takeoff column family; a generic file is
    /// just date,origin,destination (header optional).
    public static func detect(headerRow: [String]) -> FlightCSVFormat? {
        let normalized = headerRow.map(normalize)
        if normalized.contains(where: { $0.contains("gatearrival") || $0.contains("takeoff") }) {
            return .flighty
        }
        if normalized.contains("date"), normalized.contains(where: { $0 == "from" || $0 == "origin" }),
           normalized.contains(where: { $0 == "to" || $0 == "destination" }) {
            return .generic
        }
        // Headerless generic: first row already looks like data.
        if headerRow.count >= 3, parseDay(headerRow[0]) != nil,
           isIATA(headerRow[1]), isIATA(headerRow[2]) {
            return .generic
        }
        return nil
    }

    public static func parse(data: Data) throws -> (flights: [FlightRecord], skippedRows: Int) {
        let rows = CSVReader.rows(from: data)
        guard let first = rows.first else { return ([], 0) }
        guard let format = detect(headerRow: first) else {
            throw ImportError.unrecognizedFormat
        }

        switch format {
        case .flighty:
            return parseFlighty(rows: rows)
        case .generic:
            return parseGeneric(rows: rows)
        }
    }

    // MARK: - Flighty

    private static func parseFlighty(rows: [[String]]) -> ([FlightRecord], Int) {
        let header = rows[0].map(normalize)
        func column(_ names: String...) -> Int? {
            for name in names {
                if let index = header.firstIndex(of: normalize(name)) {
                    return index
                }
            }
            return nil
        }
        guard let dateCol = column("Date"),
              let fromCol = column("From"),
              let toCol = column("To") else {
            return ([], rows.count - 1)
        }
        let canceledCol = column("Canceled", "Cancelled")
        let divertedCol = column("Diverted To")
        let depActualCol = column("Gate Departure (Actual)", "Take off (Actual)")
        let depSchedCol = column("Gate Departure (Scheduled)", "Take off (Scheduled)")
        let arrActualCol = column("Gate Arrival (Actual)", "Landing (Actual)")
        let arrSchedCol = column("Gate Arrival (Scheduled)", "Landing (Scheduled)")

        var flights: [FlightRecord] = []
        var skipped = 0

        for row in rows.dropFirst() {
            func field(_ index: Int?) -> String? {
                guard let index, index < row.count else { return nil }
                let value = row[index].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
            guard let day = field(dateCol).flatMap(parseDay),
                  let origin = field(fromCol), isIATA(origin) else {
                skipped += 1
                continue
            }
            if let canceled = field(canceledCol),
               ["true", "yes", "1"].contains(canceled.lowercased()) {
                skipped += 1
                continue
            }
            var destination = field(toCol)
            if let diverted = field(divertedCol), isIATA(diverted) {
                destination = diverted
            }
            guard let dest = destination, isIATA(dest) else {
                skipped += 1
                continue
            }
            flights.append(
                FlightRecord(
                    departureDay: day,
                    originIATA: origin.uppercased(),
                    destinationIATA: dest.uppercased(),
                    departure: field(depActualCol).flatMap(parseInstant)
                        ?? field(depSchedCol).flatMap(parseInstant),
                    arrival: field(arrActualCol).flatMap(parseInstant)
                        ?? field(arrSchedCol).flatMap(parseInstant)
                )
            )
        }
        return (flights, skipped)
    }

    // MARK: - Generic

    private static func parseGeneric(rows: [[String]]) -> ([FlightRecord], Int) {
        var flights: [FlightRecord] = []
        var skipped = 0
        for (index, row) in rows.enumerated() {
            guard row.count >= 3 else {
                skipped += 1
                continue
            }
            guard let day = parseDay(row[0]), isIATA(row[1]), isIATA(row[2]) else {
                // Header row is expected to fail on row 0.
                if index > 0 { skipped += 1 }
                continue
            }
            flights.append(
                FlightRecord(
                    departureDay: day,
                    originIATA: row[1].uppercased(),
                    destinationIATA: row[2].uppercased(),
                    departure: nil,
                    arrival: nil
                )
            )
        }
        return (flights, skipped)
    }

    // MARK: - Helpers

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "(" || $0 == ")" }
    }

    static func isIATA(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.count == 3 && trimmed.allSatisfy(\.isLetter)
    }

    /// "2026-03-29" → epoch day (calendar date, no timezone).
    static func parseDay(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespaces).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day), year > 1900 else {
            return nil
        }
        return EpochDay.daysFromCivil(year: year, month: month, day: day)
    }

    /// ISO8601 with or without fractional seconds / offset.
    static func parseInstant(_ value: String) -> Date? {
        let formats = [ISO8601DateFormatter(), ISO8601DateFormatter()]
        formats[0].formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formats[1].formatOptions = [.withInternetDateTime]
        for formatter in formats {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

public enum ImportError: Error, Equatable {
    case unrecognizedFormat
}

/// A flight yields any-presence facts: the departure day in the origin
/// country and the arrival day in the destination country. When an arrival
/// instant exists it's bucketed in the DESTINATION AIRPORT's timezone
/// (overnight LHR→HND lands "tomorrow" in Japan); otherwise the arrival is
/// assumed same-day as departure — a documented undercount for overnight
/// flights exported without times.
public func flightDayFacts(
    flights: [FlightRecord],
    airports: AirportIndex,
    lookup: GeoLookup
) -> (facts: [ImportDayFact], unknownIATAs: Set<String>, flightsUsed: Int) {
    var aggregate: [String: ImportDayFact] = [:]
    var unknown: Set<String> = []
    var used = 0

    func add(day: Int, country: String, at instant: Date?) {
        let key = "\(day)|\(country)"
        let stamp = instant ?? EpochDay(value: day).startDate(in: TimeZone(identifier: "UTC")!)
        if let existing = aggregate[key] {
            aggregate[key] = ImportDayFact(
                day: day,
                countryCode: country,
                evidenceCount: existing.evidenceCount + 1,
                first: min(existing.first, stamp),
                last: max(existing.last, stamp)
            )
        } else {
            aggregate[key] = ImportDayFact(
                day: day, countryCode: country, evidenceCount: 1, first: stamp, last: stamp
            )
        }
    }

    for flight in flights {
        guard let origin = airports.airport(iata: flight.originIATA) else {
            unknown.insert(flight.originIATA)
            continue
        }
        guard let destination = airports.airport(iata: flight.destinationIATA) else {
            unknown.insert(flight.destinationIATA)
            continue
        }
        used += 1

        add(day: flight.departureDay, country: origin.countryCode, at: flight.departure)

        let arrivalDay: Int
        if let arrival = flight.arrival {
            let tz = lookup.timeZone(at: destination.point) ?? TimeZone(identifier: "UTC")!
            arrivalDay = EpochDay(date: arrival, timeZone: tz).value
        } else {
            arrivalDay = flight.departureDay
        }
        add(day: arrivalDay, country: destination.countryCode, at: flight.arrival)
    }

    return (Array(aggregate.values), unknown, used)
}
