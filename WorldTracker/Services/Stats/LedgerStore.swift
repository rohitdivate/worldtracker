import Foundation
import Observation
import SwiftData
import WorldTrackerKit

extension Notification.Name {
    /// Posted after any write that affects the travel ledger.
    static let ledgerDidChange = Notification.Name("beenthere.ledgerDidChange")
}

/// Main-actor cache in front of the DayLedgerResolver. All screens (calendar,
/// home, stats, map) read resolved days through this one object, so the
/// gap-fill policy and manual edits re-render everything instantly.
@MainActor
@Observable
final class LedgerStore {
    private let container: ModelContainer

    /// Bumped on every ledger mutation — views naturally depend on it via any
    /// call that reads cached data.
    private(set) var changeToken = 0
    @ObservationIgnored private var cache: [String: [ResolvedDay]] = [:]
    @ObservationIgnored private var cachedEarliestDay: Int??

    var homeCountry: String? {
        get { UserDefaults.standard.string(forKey: "homeCountry") }
        set {
            UserDefaults.standard.set(newValue, forKey: "homeCountry")
            invalidate()
        }
    }

    /// "leaveEmpty" | "assume" | "short"
    var gapFillModeRaw: String {
        get { UserDefaults.standard.string(forKey: "gapFillMode") ?? "short" }
        set {
            UserDefaults.standard.set(newValue, forKey: "gapFillMode")
            invalidate()
        }
    }

    var gapFillMaxDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "gapFillMaxDays")
            return stored == 0 ? 3 : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "gapFillMaxDays")
            invalidate()
        }
    }

    var gapFillPolicy: GapFillPolicy {
        switch gapFillModeRaw {
        case "leaveEmpty": return .leaveEmpty
        case "assume": return .assumePreviousLocation
        default: return .fillShortGaps(maxDays: gapFillMaxDays)
        }
    }

    init(container: ModelContainer) {
        self.container = container
        NotificationCenter.default.addObserver(
            forName: .ledgerDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.invalidate()
            }
        }
    }

    func invalidate() {
        cache.removeAll()
        cachedEarliestDay = nil
        changeToken += 1
        scheduleSnapshotWrite()
    }

    /// Debounced widget-snapshot refresh — bursts of ledger changes (backfill,
    /// import) collapse into one write + one WidgetKit reload.
    @ObservationIgnored private var snapshotTask: Task<Void, Never>?

    private func scheduleSnapshotWrite() {
        snapshotTask?.cancel()
        snapshotTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self else { return }
            SharedSnapshotStore.write(from: self)
        }
    }

    // MARK: - Resolution

    func resolvedDays(in range: ClosedRange<Int>) -> [ResolvedDay] {
        let key = "\(range.lowerBound)-\(range.upperBound)-\(gapFillModeRaw)-\(gapFillMaxDays)-\(homeCountry ?? "-")"
        if let hit = cache[key] { return hit }

        let context = container.mainContext
        let lower = range.lowerBound
        let upper = range.upperBound

        let factPredicate = #Predicate<CountryDayFact> {
            $0.epochDay >= lower && $0.epochDay <= upper
        }
        let facts = (try? context.fetch(FetchDescriptor(predicate: factPredicate))) ?? []

        let annotationPredicate = #Predicate<DayAnnotation> {
            $0.epochDay >= lower && $0.epochDay <= upper
        }
        let annotations = (try? context.fetch(FetchDescriptor(predicate: annotationPredicate))) ?? []

        let resolver = DayLedgerResolver(homeCountry: homeCountry, gapFill: gapFillPolicy)
        let resolved = resolver.resolve(
            facts: facts.map {
                CountryFactInput(
                    day: $0.epochDay,
                    countryCode: $0.countryCode,
                    source: FactSource(rawValue: $0.sourceRaw) ?? .gps,
                    confidence: $0.confidence,
                    evidenceCount: $0.evidenceCount
                )
            },
            annotations: annotations.map {
                DayAnnotationInput(
                    day: $0.epochDay,
                    isCleared: $0.isCleared,
                    hasNote: ($0.note?.isEmpty == false)
                )
            },
            range: range
        )
        cache[key] = resolved
        return resolved
    }

    func day(_ epochDay: Int) -> ResolvedDay {
        resolvedDays(in: epochDay...epochDay).first
            ?? ResolvedDay(day: epochDay, countryCodes: [], source: nil, isFilled: false)
    }

    /// First day with any recorded fact (nil until tracking/backfill produce data).
    var earliestDay: Int? {
        if let cached = cachedEarliestDay { return cached }
        var descriptor = FetchDescriptor<CountryDayFact>(
            sortBy: [SortDescriptor(\.epochDay, order: .forward)]
        )
        descriptor.fetchLimit = 1
        let value = (try? container.mainContext.fetch(descriptor))?.first?.epochDay
        cachedEarliestDay = .some(value)
        return value
    }

    var todayEpoch: Int {
        EpochDay(date: Date(), timeZone: TimeZone.current).value
    }

    /// Consecutive days (ending today) with the same primary country.
    func currentStay() -> (countryCode: String, days: Int)? {
        let today = todayEpoch
        let window = resolvedDays(in: (today - 400)...today)
        guard let code = window.last?.countryCodes.first else { return nil }
        var streak = 0
        for day in window.reversed() {
            if day.countryCodes.first == code {
                streak += 1
            } else {
                break
            }
        }
        return (code, streak)
    }

    /// Days spent in a country this calendar year (any presence).
    func daysThisYear(in countryCode: String) -> Int {
        let today = todayEpoch
        let (year, _, _) = EpochDay(value: today).civil()
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let days = resolvedDays(in: jan1...today)
        return days.filter { $0.countryCodes.contains(countryCode) }.count
    }

    func stats(in range: ClosedRange<Int>) -> TravelStats {
        DayLedgerResolver.stats(for: resolvedDays(in: range), home: homeCountry)
    }

    func segments(in range: ClosedRange<Int>) -> [TripSegment] {
        DayLedgerResolver.segments(from: resolvedDays(in: range))
    }
}
