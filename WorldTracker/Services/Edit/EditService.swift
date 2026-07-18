import Foundation
import SwiftData
import WorldTrackerKit

/// All manual corrections go through here. Manual facts always outrank
/// automatic evidence in the resolver, and survive every photo re-sync.
@MainActor
final class EditService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    private var context: ModelContext { container.mainContext }

    /// Set the country (or countries) for a single day. Replaces any prior
    /// manual verdict for that day.
    func setCountries(_ codes: [String], day: Int) {
        removeManualFacts(days: [day])
        for code in codes {
            context.insert(
                CountryDayFact(
                    epochDay: day,
                    countryCode: code,
                    sourceRaw: FactSource.manual.rawValue,
                    confidence: 1.0,
                    seenAt: Date()
                )
            )
        }
        uncleara(day: day)
        save()
    }

    /// Manual trip entry: one country across an inclusive day range.
    func setCountry(_ code: String, from startDay: Int, to endDay: Int) {
        guard startDay <= endDay else { return }
        let days = Array(startDay...endDay)
        removeManualFacts(days: days)
        for day in days {
            context.insert(
                CountryDayFact(
                    epochDay: day,
                    countryCode: code,
                    sourceRaw: FactSource.manual.rawValue,
                    confidence: 1.0,
                    seenAt: Date()
                )
            )
            uncleara(day: day)
        }
        save()
    }

    /// Mark a day as "no data": hides all automatic evidence and blocks
    /// gap-fill through it.
    func clearDay(_ day: Int) {
        removeManualFacts(days: [day])
        annotation(for: day).isCleared = true
        save()
    }

    /// Remove all manual overrides and the cleared flag — the automatic
    /// evidence shows through again.
    func revertToAutomatic(day: Int) {
        removeManualFacts(days: [day])
        if let existing = fetchAnnotation(day) {
            existing.isCleared = false
            if existing.note == nil || existing.note?.isEmpty == true {
                context.delete(existing)
            }
        }
        save()
    }

    func setNote(_ text: String, day: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let existing = fetchAnnotation(day) {
                existing.note = nil
                if !existing.isCleared {
                    context.delete(existing)
                }
            }
        } else {
            annotation(for: day).note = trimmed
        }
        save()
    }

    func note(for day: Int) -> String {
        fetchAnnotation(day)?.note ?? ""
    }

    func hasClearedAnnotation(day: Int) -> Bool {
        fetchAnnotation(day)?.isCleared == true
    }

    func hasManualFacts(day: Int) -> Bool {
        let manual = FactSource.manual.rawValue
        let predicate = #Predicate<CountryDayFact> {
            $0.epochDay == day && $0.sourceRaw == manual
        }
        return ((try? context.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0) > 0
    }

    /// Evidence snapshot for the day editor.
    func evidence(for day: Int) -> DayEvidence {
        let factPredicate = #Predicate<CountryDayFact> { $0.epochDay == day }
        let facts = (try? context.fetch(FetchDescriptor(predicate: factPredicate))) ?? []

        let photoPredicate = #Predicate<PhotoEvidence> { $0.epochDay == day }
        let photos = (try? context.fetch(FetchDescriptor(predicate: photoPredicate))) ?? []

        let samplePredicate = #Predicate<LocationSample> { $0.epochDay == day }
        let sampleCount = (try? context.fetchCount(FetchDescriptor(predicate: samplePredicate))) ?? 0

        return DayEvidence(
            facts: facts.map {
                DayEvidence.Fact(
                    countryCode: $0.countryCode,
                    source: FactSource(rawValue: $0.sourceRaw) ?? .gps,
                    evidenceCount: $0.evidenceCount
                )
            },
            photoPlaces: photos.map {
                DayEvidence.PhotoPlace(
                    city: $0.city,
                    countryCode: $0.countryCode,
                    photoCount: $0.photoCount
                )
            },
            locationSampleCount: sampleCount
        )
    }

    // MARK: - Internals

    private func removeManualFacts(days: [Int]) {
        let manual = FactSource.manual.rawValue
        for day in days {
            let predicate = #Predicate<CountryDayFact> {
                $0.epochDay == day && $0.sourceRaw == manual
            }
            for fact in (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? [] {
                context.delete(fact)
            }
        }
    }

    private func fetchAnnotation(_ day: Int) -> DayAnnotation? {
        let predicate = #Predicate<DayAnnotation> { $0.epochDay == day }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func annotation(for day: Int) -> DayAnnotation {
        if let existing = fetchAnnotation(day) { return existing }
        let fresh = DayAnnotation(epochDay: day)
        context.insert(fresh)
        return fresh
    }

    private func uncleara(day: Int) {
        fetchAnnotation(day)?.isCleared = false
    }

    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
    }
}

struct DayEvidence {
    struct Fact: Identifiable {
        var id: String { "\(countryCode)-\(source.rawValue)" }
        let countryCode: String
        let source: FactSource
        let evidenceCount: Int
    }

    struct PhotoPlace: Identifiable {
        let id = UUID()
        let city: String?
        let countryCode: String?
        let photoCount: Int
    }

    let facts: [Fact]
    let photoPlaces: [PhotoPlace]
    let locationSampleCount: Int
}
