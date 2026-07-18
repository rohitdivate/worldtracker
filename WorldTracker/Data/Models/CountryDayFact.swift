import Foundation
import SwiftData

/// The ledger: one row per (day, country, source) — facts, never verdicts.
/// The DayLedgerResolver (WorldTrackerKit) turns these into per-day country
/// assignments at query time with precedence manual > gps/visit > photo >
/// timezoneHint. CloudKit-compatible: defaults everywhere, no uniques.
@Model
final class CountryDayFact {
    var id: UUID = UUID()
    /// Days since 1970-01-01, bucketed in the coordinate's own timezone.
    var epochDay: Int = 0
    /// ISO 3166-1 alpha-2.
    var countryCode: String = ""
    /// FactSource.rawValue: gps | visit | photo | manual | timezoneHint
    var sourceRaw: String = "gps"
    var confidence: Double = 1.0
    /// How many independent events support this fact (upserts increment).
    var evidenceCount: Int = 1
    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var createdAt: Date = Date()
    /// Photo-backfill generation this row belongs to (0 = pre-generation
    /// data or non-photo sources). The generation-swap re-scan writes G+1
    /// rows alongside G and deletes G only after a complete scan.
    var scanGeneration: Int = 0

    init(
        epochDay: Int,
        countryCode: String,
        sourceRaw: String,
        confidence: Double,
        seenAt: Date
    ) {
        self.id = UUID()
        self.epochDay = epochDay
        self.countryCode = countryCode
        self.sourceRaw = sourceRaw
        self.confidence = confidence
        self.evidenceCount = 1
        self.firstSeenAt = seenAt
        self.lastSeenAt = seenAt
        self.createdAt = Date()
    }
}

/// Sparse per-day extras: notes and the manual "this day has no data" marker.
@Model
final class DayAnnotation {
    var id: UUID = UUID()
    var epochDay: Int = 0
    var note: String?
    /// Manual "clear this day" — forces the day empty and blocks gap-fill.
    var isCleared: Bool = false
    var updatedAt: Date = Date()

    init(epochDay: Int) {
        self.id = UUID()
        self.epochDay = epochDay
        self.updatedAt = Date()
    }
}
