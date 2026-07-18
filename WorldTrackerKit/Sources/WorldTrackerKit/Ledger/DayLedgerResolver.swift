import Foundation

/// Plain mirror of a stored CountryDayFact row.
public struct CountryFactInput: Sendable, Equatable {
    public let day: Int
    public let countryCode: String
    public let source: FactSource
    public let confidence: Double
    public let evidenceCount: Int

    public init(day: Int, countryCode: String, source: FactSource, confidence: Double, evidenceCount: Int = 1) {
        self.day = day
        self.countryCode = countryCode
        self.source = source
        self.confidence = confidence
        self.evidenceCount = evidenceCount
    }
}

/// Plain mirror of a stored DayAnnotation row.
public struct DayAnnotationInput: Sendable, Equatable {
    public let day: Int
    public let isCleared: Bool
    public let hasNote: Bool

    public init(day: Int, isCleared: Bool, hasNote: Bool) {
        self.day = day
        self.isCleared = isCleared
        self.hasNote = hasNote
    }
}

/// What to do with days that have no evidence at all.
public enum GapFillPolicy: Sendable, Equatable {
    case leaveEmpty
    /// "Assume you stayed in each location until evidence moves you."
    case assumePreviousLocation
    /// Fill gaps up to N days with the last known location; leave longer ones.
    case fillShortGaps(maxDays: Int)
}

/// The verdict for one calendar day.
public struct ResolvedDay: Sendable, Equatable {
    public let day: Int
    /// Ordered by evidence strength. 0 = unknown, 2+ = border-crossing day.
    public let countryCodes: [String]
    /// Winning provenance tier (nil for empty days).
    public let source: FactSource?
    /// True when gap-fill inferred this day (no direct evidence).
    public let isFilled: Bool
    public let hasNote: Bool

    public init(day: Int, countryCodes: [String], source: FactSource?, isFilled: Bool, hasNote: Bool = false) {
        self.day = day
        self.countryCodes = countryCodes
        self.source = source
        self.isFilled = isFilled
        self.hasNote = hasNote
    }
}

/// A maximal run of consecutive days during which a country was present.
/// Border days belong to BOTH neighboring segments (any-presence model).
public struct TripSegment: Sendable, Equatable, Identifiable {
    public var id: String { "\(countryCode)-\(startDay)" }
    public let countryCode: String
    public let startDay: Int
    public let endDay: Int
    public var dayCount: Int { endDay - startDay + 1 }

    public init(countryCode: String, startDay: Int, endDay: Int) {
        self.countryCode = countryCode
        self.startDay = startDay
        self.endDay = endDay
    }
}

public struct TravelStats: Sendable, Equatable {
    public let countriesVisited: Int
    public let borderCrossings: Int
    /// Days not spent (exclusively) in the home country.
    public let travelDays: Int
    /// Any-presence: a border day counts fully in both countries.
    public let daysPerCountry: [String: Int]

    public init(countriesVisited: Int, borderCrossings: Int, travelDays: Int, daysPerCountry: [String: Int]) {
        self.countriesVisited = countriesVisited
        self.borderCrossings = borderCrossings
        self.travelDays = travelDays
        self.daysPerCountry = daysPerCountry
    }
}

/// Turns stored facts into per-day verdicts. Pure, deterministic, fast —
/// the entire app queries through this.
///
/// Precedence: manual (exclusive) > gps/visit > photo > timezoneHint.
/// A cleared day is empty and blocks gap-fill from crossing it.
public struct DayLedgerResolver: Sendable {
    public let homeCountry: String?
    public let gapFill: GapFillPolicy

    public init(homeCountry: String?, gapFill: GapFillPolicy) {
        self.homeCountry = homeCountry
        self.gapFill = gapFill
    }

    public func resolve(
        facts: [CountryFactInput],
        annotations: [DayAnnotationInput],
        range: ClosedRange<Int>
    ) -> [ResolvedDay] {
        var factsByDay: [Int: [CountryFactInput]] = [:]
        for fact in facts where range.contains(fact.day) {
            factsByDay[fact.day, default: []].append(fact)
        }
        var annotationsByDay: [Int: DayAnnotationInput] = [:]
        for annotation in annotations where range.contains(annotation.day) {
            annotationsByDay[annotation.day] = annotation
        }

        var days: [ResolvedDay] = []
        days.reserveCapacity(range.count)

        for day in range.lowerBound...range.upperBound {
            let annotation = annotationsByDay[day]
            let hasNote = annotation?.hasNote ?? false

            if annotation?.isCleared == true {
                days.append(ResolvedDay(day: day, countryCodes: [], source: nil, isFilled: false, hasNote: hasNote))
                continue
            }

            let dayFacts = factsByDay[day] ?? []
            let verdict = Self.verdict(for: dayFacts)
            days.append(
                ResolvedDay(
                    day: day,
                    countryCodes: verdict.codes,
                    source: verdict.source,
                    isFilled: false,
                    hasNote: hasNote
                )
            )
        }

        applyGapFill(&days, annotationsByDay: annotationsByDay)
        return days
    }

    private static func verdict(for facts: [CountryFactInput]) -> (codes: [String], source: FactSource?) {
        guard !facts.isEmpty else { return ([], nil) }

        let tiers: [[FactSource]] = [
            [.manual],
            [.gps, .visit],
            [.photo],
            [.timezoneHint],
        ]
        for tier in tiers {
            let tierFacts = facts.filter { tier.contains($0.source) }
            guard !tierFacts.isEmpty else { continue }

            // Merge same-country facts within the tier; order by weight.
            var weight: [String: Double] = [:]
            for fact in tierFacts {
                weight[fact.countryCode, default: 0] +=
                    fact.confidence * Double(max(1, fact.evidenceCount))
            }
            let codes = weight.keys.sorted {
                (weight[$0] ?? 0, $1) > (weight[$1] ?? 0, $0)
            }
            let source: FactSource
            if tier.contains(.manual) {
                source = .manual
            } else if tier.contains(.gps) {
                source = tierFacts.contains { $0.source == .gps } ? .gps : .visit
            } else {
                source = tierFacts[0].source
            }
            return (codes, source)
        }
        return ([], nil)
    }

    private func applyGapFill(
        _ days: inout [ResolvedDay],
        annotationsByDay: [Int: DayAnnotationInput]
    ) {
        guard gapFill != .leaveEmpty else { return }

        var lastKnown: String?
        var gapStart: Int?

        func fill(from start: Int, to end: Int, with code: String) {
            for i in start...end {
                days[i] = ResolvedDay(
                    day: days[i].day,
                    countryCodes: [code],
                    source: nil,
                    isFilled: true,
                    hasNote: days[i].hasNote
                )
            }
        }

        for index in days.indices {
            let day = days[index]
            let cleared = annotationsByDay[day.day]?.isCleared == true

            if cleared {
                // A cleared day hard-stops the chain — but carry-forward
                // filling still applies to the gap BEFORE it ("you stayed
                // there until the day you marked unknown").
                if let start = gapStart, let code = lastKnown,
                   case .assumePreviousLocation = gapFill {
                    fill(from: start, to: index - 1, with: code)
                }
                lastKnown = nil
                gapStart = nil
                continue
            }

            if day.countryCodes.isEmpty {
                if gapStart == nil { gapStart = index }
                continue
            }

            // Known day: close any open gap behind it.
            if let start = gapStart, let code = lastKnown {
                let length = index - start
                switch gapFill {
                case .assumePreviousLocation:
                    fill(from: start, to: index - 1, with: code)
                case .fillShortGaps(let maxDays):
                    if length <= maxDays {
                        fill(from: start, to: index - 1, with: code)
                    }
                case .leaveEmpty:
                    break
                }
            }
            gapStart = nil
            lastKnown = day.countryCodes.first
        }

        // Trailing gap (up to "today"): assume-previous extends to the end.
        if let start = gapStart, let code = lastKnown {
            switch gapFill {
            case .assumePreviousLocation:
                fill(from: start, to: days.count - 1, with: code)
            case .fillShortGaps(let maxDays):
                if days.count - start <= maxDays {
                    fill(from: start, to: days.count - 1, with: code)
                }
            case .leaveEmpty:
                break
            }
        }
    }

    // MARK: - Derived views

    /// Per-country maximal consecutive runs. Border days join both runs.
    public static func segments(from days: [ResolvedDay]) -> [TripSegment] {
        var open: [String: (start: Int, end: Int)] = [:]
        var out: [TripSegment] = []

        for day in days {
            let present = Set(day.countryCodes)
            // Close runs for countries no longer present.
            for (code, run) in open where !present.contains(code) {
                out.append(TripSegment(countryCode: code, startDay: run.start, endDay: run.end))
                open.removeValue(forKey: code)
            }
            // Extend or start runs.
            for code in present {
                if let run = open[code] {
                    open[code] = (run.start, day.day)
                } else {
                    open[code] = (day.day, day.day)
                }
            }
        }
        for (code, run) in open {
            out.append(TripSegment(countryCode: code, startDay: run.start, endDay: run.end))
        }
        return out.sorted { ($0.startDay, $0.countryCode) > ($1.startDay, $1.countryCode) }
    }

    public static func stats(for days: [ResolvedDay], home: String?) -> TravelStats {
        var perCountry: [String: Int] = [:]
        var travelDays = 0

        for day in days {
            guard !day.countryCodes.isEmpty else { continue }
            for code in day.countryCodes {
                perCountry[code, default: 0] += 1
            }
            if day.countryCodes != [home].compactMap({ $0 }) {
                travelDays += 1
            }
        }

        // A crossing is a boundary between consecutive stays: the segment
        // chain (which merges border-day overlaps) has exactly one fewer
        // crossing than it has stays.
        let stayCount = segments(from: days).count
        let crossings = max(0, stayCount - 1)

        return TravelStats(
            countriesVisited: perCountry.keys.count,
            borderCrossings: crossings,
            travelDays: travelDays,
            daysPerCountry: perCountry
        )
    }
}
