import Foundation
import SwiftData
import WorldTrackerKit

/// Full-fidelity backup and restore. The archive holds facts (not the
/// verdicts computed from them), day notes and "no data" marks, and the
/// settings that shape how facts are read. Restoring only adds: see
/// `BackupMergePlan`.
@MainActor
final class BackupService {
    struct RestoreSummary {
        let facts: Int
        let annotations: Int
        let rules: Int
        let wishlist: Int
        let plans: Int
        let adoptedProfile: Bool

        var isEmpty: Bool {
            facts + annotations + rules + wishlist + plans == 0 && !adoptedProfile
        }

        var message: String {
            if isEmpty { return "Everything in that backup is already on this device." }
            var parts: [String] = []
            if facts > 0 { parts.append("\(facts.grouped) day records") }
            if annotations > 0 { parts.append("\(annotations) notes and marks") }
            if rules > 0 { parts.append("\(rules) day \(rules == 1 ? "limit" : "limits")") }
            if plans > 0 { parts.append("\(plans) planned \(plans == 1 ? "trip" : "trips")") }
            if wishlist > 0 { parts.append("\(wishlist) wishlist \(wishlist == 1 ? "country" : "countries")") }
            if adoptedProfile { parts.append("your home history") }
            return "Added " + parts.joined(separator: ", ") + ". Nothing already here was changed."
        }
    }

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    func makeArchive() -> BackupArchive {
        let shared = AppContainer.shared
        let store = shared.ledgerStore
        let facts = (try? context.fetch(FetchDescriptor<CountryDayFact>())) ?? []
        let annotations = (try? context.fetch(FetchDescriptor<DayAnnotation>())) ?? []
        return BackupArchive(
            exportedDay: store.todayEpoch,
            facts: facts
                .map {
                    BackupArchive.Fact(
                        day: $0.epochDay,
                        countryCode: $0.countryCode,
                        source: $0.sourceRaw,
                        confidence: $0.confidence,
                        evidenceCount: $0.evidenceCount,
                        firstSeen: $0.firstSeenAt?.timeIntervalSince1970,
                        lastSeen: $0.lastSeenAt?.timeIntervalSince1970,
                        scanGeneration: $0.scanGeneration
                    )
                }
                .sorted { ($0.day, $0.countryCode, $0.source) < ($1.day, $1.countryCode, $1.source) },
            annotations: annotations
                .map { BackupArchive.Annotation(day: $0.epochDay, isCleared: $0.isCleared, note: $0.note) }
                .sorted { $0.day < $1.day },
            homeTimeline: store.homeTimeline,
            gapFillMode: store.gapFillModeRaw,
            gapFillMaxDays: store.gapFillMaxDays,
            limitRules: shared.dayLimitStore.rules,
            wishlist: shared.insightsStore.wishlistCodes,
            plans: shared.planStore.plans
        )
    }

    /// Writes the archive to a temporary file for the share sheet.
    func exportFile() -> URL? {
        let archive = makeArchive()
        guard let data = try? archive.encoded() else { return nil }
        let c = EpochDay(value: archive.exportedDay).civil()
        let name = String(format: "BeenThere-backup-%04d-%02d-%02d.json", c.year, c.month, c.day)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func restore(from url: URL) throws -> RestoreSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            throw BackupArchive.BackupError.unreadable
        }
        return try restore(BackupArchive.decode(data))
    }

    func restore(_ archive: BackupArchive) throws -> RestoreSummary {
        let shared = AppContainer.shared
        let store = shared.ledgerStore
        let existingFacts = (try? context.fetch(FetchDescriptor<CountryDayFact>())) ?? []
        let existingAnnotations = (try? context.fetch(FetchDescriptor<DayAnnotation>())) ?? []

        let plan = BackupMergePlan.plan(
            archive: archive,
            existingFacts: Set(existingFacts.map {
                BackupArchive.FactKey(day: $0.epochDay, countryCode: $0.countryCode, source: $0.sourceRaw)
            }),
            // An annotation row that carries nothing doesn't block a restore.
            existingAnnotationDays: Set(existingAnnotations
                .filter { $0.isCleared || $0.note?.isEmpty == false }
                .map(\.epochDay)),
            existingRuleIDs: Set(shared.dayLimitStore.rules.map(\.id)),
            existingWishlist: Set(shared.insightsStore.wishlistCodes),
            existingPlanIDs: Set(shared.planStore.plans.map(\.id)),
            hasHome: !store.homeTimeline.isEmpty
        )

        for fact in plan.facts {
            let seen = Date(timeIntervalSince1970: fact.lastSeen ?? fact.firstSeen ?? 0)
            let row = CountryDayFact(
                epochDay: fact.day, countryCode: fact.countryCode,
                sourceRaw: fact.source, confidence: fact.confidence, seenAt: seen
            )
            row.evidenceCount = fact.evidenceCount
            row.firstSeenAt = fact.firstSeen.map(Date.init(timeIntervalSince1970:))
            row.lastSeenAt = fact.lastSeen.map(Date.init(timeIntervalSince1970:))
            row.scanGeneration = fact.scanGeneration
            context.insert(row)
        }
        let emptyByDay = Dictionary(
            existingAnnotations.map { ($0.epochDay, $0) }, uniquingKeysWith: { first, _ in first }
        )
        for annotation in plan.annotations {
            let row = emptyByDay[annotation.day] ?? {
                let created = DayAnnotation(epochDay: annotation.day)
                context.insert(created)
                return created
            }()
            row.isCleared = annotation.isCleared
            row.note = annotation.note
            row.updatedAt = Date()
        }
        try context.save()

        if plan.adoptsProfile, let timeline = archive.homeTimeline {
            store.homeTimeline = timeline
            if let mode = archive.gapFillMode { store.gapFillModeRaw = mode }
            if let maxDays = archive.gapFillMaxDays { store.gapFillMaxDays = maxDays }
        }
        for code in plan.wishlist { shared.insightsStore.toggleWish(code) }
        for trip in plan.plans { shared.planStore.save(trip) }
        // Rules last: adding one refreshes widgets and reminders, which
        // should see the restored ledger.
        NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
        for rule in plan.rules { shared.dayLimitStore.add(rule) }

        return RestoreSummary(
            facts: plan.facts.count,
            annotations: plan.annotations.count,
            rules: plan.rules.count,
            wishlist: plan.wishlist.count,
            plans: plan.plans.count,
            adoptedProfile: plan.adoptsProfile
        )
    }
}
