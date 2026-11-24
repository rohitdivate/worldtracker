import Foundation

/// Everything needed to rebuild a ledger on another install: the facts
/// themselves (not the verdicts computed from them), day notes and "no
/// data" marks, and the settings that shape how facts are read.
///
/// The CSV and JSON exports are a record of *resolved days* for people to
/// read. This is the other thing: a full-fidelity copy for the app to read
/// back. Places and photo evidence are left out on purpose; a photo re-scan
/// rebuilds them.
public struct BackupArchive: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    public static let fileExtension = "json"

    public struct Fact: Codable, Sendable, Hashable {
        public var day: Int
        public var countryCode: String
        /// `FactSource` raw value, kept as a string so an archive from a
        /// newer build with a source this one doesn't know still decodes.
        public var source: String
        public var confidence: Double
        public var evidenceCount: Int
        public var firstSeen: Double?
        public var lastSeen: Double?
        public var scanGeneration: Int

        public init(
            day: Int, countryCode: String, source: String, confidence: Double,
            evidenceCount: Int = 1, firstSeen: Double? = nil, lastSeen: Double? = nil,
            scanGeneration: Int = 0
        ) {
            self.day = day
            self.countryCode = countryCode
            self.source = source
            self.confidence = confidence
            self.evidenceCount = evidenceCount
            self.firstSeen = firstSeen
            self.lastSeen = lastSeen
            self.scanGeneration = scanGeneration
        }

        /// What makes two fact rows "the same fact".
        public var key: FactKey { FactKey(day: day, countryCode: countryCode, source: source) }
    }

    public struct FactKey: Hashable, Sendable {
        public let day: Int
        public let countryCode: String
        public let source: String

        public init(day: Int, countryCode: String, source: String) {
            self.day = day
            self.countryCode = countryCode
            self.source = source
        }
    }

    public struct Annotation: Codable, Sendable, Hashable {
        public var day: Int
        public var isCleared: Bool
        public var note: String?

        public init(day: Int, isCleared: Bool, note: String?) {
            self.day = day
            self.isCleared = isCleared
            self.note = note
        }
    }

    public var version: Int
    /// Epoch day the archive was written.
    public var exportedDay: Int
    public var facts: [Fact]
    public var annotations: [Annotation]
    public var homeTimeline: HomeTimeline?
    public var gapFillMode: String?
    public var gapFillMaxDays: Int?
    public var limitRules: [DayLimitRule]
    public var wishlist: [String]
    public var plans: [PlannedTrip]

    public init(
        version: Int = BackupArchive.currentVersion,
        exportedDay: Int,
        facts: [Fact],
        annotations: [Annotation],
        homeTimeline: HomeTimeline? = nil,
        gapFillMode: String? = nil,
        gapFillMaxDays: Int? = nil,
        limitRules: [DayLimitRule] = [],
        wishlist: [String] = [],
        plans: [PlannedTrip] = []
    ) {
        self.version = version
        self.exportedDay = exportedDay
        self.facts = facts
        self.annotations = annotations
        self.homeTimeline = homeTimeline
        self.gapFillMode = gapFillMode
        self.gapFillMaxDays = gapFillMaxDays
        self.limitRules = limitRules
        self.wishlist = wishlist
        self.plans = plans
    }

    public enum BackupError: Error, Equatable {
        /// Written by a newer build than this one can read.
        case newerVersion(Int)
        case unreadable
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> BackupArchive {
        struct Header: Decodable { let version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw BackupError.unreadable
        }
        guard header.version <= currentVersion else {
            throw BackupError.newerVersion(header.version)
        }
        guard let archive = try? JSONDecoder().decode(BackupArchive.self, from: data) else {
            throw BackupError.unreadable
        }
        return archive
    }
}

/// What restoring an archive into an existing ledger should add. A restore
/// only ever adds: nothing already on the device is changed or removed.
public struct BackupMergePlan: Sendable, Equatable {
    public let facts: [BackupArchive.Fact]
    public let annotations: [BackupArchive.Annotation]
    public let rules: [DayLimitRule]
    public let wishlist: [String]
    public let plans: [PlannedTrip]
    /// Adopt the archive's home history and gap-fill settings: only when
    /// this install has no home set, so a configured device keeps its own.
    public let adoptsProfile: Bool

    public var isEmpty: Bool {
        facts.isEmpty && annotations.isEmpty && rules.isEmpty
            && wishlist.isEmpty && plans.isEmpty && !adoptsProfile
    }

    public static func plan(
        archive: BackupArchive,
        existingFacts: Set<BackupArchive.FactKey>,
        existingAnnotationDays: Set<Int>,
        existingRuleIDs: Set<String>,
        existingWishlist: Set<String>,
        existingPlanIDs: Set<String>,
        hasHome: Bool
    ) -> BackupMergePlan {
        var seen = existingFacts
        var facts: [BackupArchive.Fact] = []
        for fact in archive.facts where seen.insert(fact.key).inserted {
            facts.append(fact)
        }
        var days = existingAnnotationDays
        let annotations = archive.annotations.filter {
            ($0.isCleared || $0.note?.isEmpty == false) && days.insert($0.day).inserted
        }
        return BackupMergePlan(
            facts: facts,
            annotations: annotations,
            rules: archive.limitRules.filter { !existingRuleIDs.contains($0.id) },
            wishlist: archive.wishlist.filter { !existingWishlist.contains($0) },
            plans: archive.plans.filter { !existingPlanIDs.contains($0.id) },
            adoptsProfile: !hasHome && archive.homeTimeline?.isEmpty == false
        )
    }
}
