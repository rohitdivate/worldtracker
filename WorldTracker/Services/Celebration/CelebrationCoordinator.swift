import Foundation
import Observation
import WorldTrackerKit

/// Decides when a celebration moment is actually shown.
/// Detection happens elsewhere (DB-truth at the live-ingest write, the
/// milestone tracker's snapshot diff); this class owns queuing, suppression,
/// and dedupe so each moment lands exactly once, in the foreground, never on
/// top of onboarding or a running backfill/import.
@MainActor
@Observable
final class CelebrationCoordinator {
    struct Celebration: Identifiable, Equatable {
        let id = UUID()
        let countryCode: String
        /// "COUNTRY #N" — distinct countries ever recorded, including this one.
        let number: Int
        let city: String?
    }

    struct MilestoneMoment: Identifiable, Equatable {
        let id = UUID()
        let milestone: Milestone
        /// Lifetime distinct countries at the moment of crossing.
        let countries: Int
        /// Top visited codes for the flag cascade.
        let flags: [String]
    }

    enum CelebrationEvent: Identifiable, Equatable {
        case newCountry(Celebration)
        case milestone(MilestoneMoment)

        var id: UUID {
            switch self {
            case .newCountry(let c): return c.id
            case .milestone(let m): return m.id
            }
        }
    }

    private(set) var current: CelebrationEvent?
    private var queue: [CelebrationEvent] = []

    /// Called from the ingest path (already deduped by the DB-truth check;
    /// this second layer guards against edits that delete and re-create).
    func newCountryDetected(code: String, number: Int, city: String?) {
        let key = "celebrated-\(code)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        queue.append(.newCountry(Celebration(countryCode: code, number: number, city: city)))
        presentIfPossible()
    }

    /// Called by the MilestoneTracker — dedupe already handled there via the
    /// awarded-keys set.
    func milestoneReached(_ milestone: Milestone, countries: Int, flags: [String]) {
        queue.append(.milestone(MilestoneMoment(
            milestone: milestone, countries: countries, flags: flags
        )))
        presentIfPossible()
    }

    /// Re-checked whenever the app comes forward or a blocker finishes.
    func presentIfPossible() {
        guard current == nil, !queue.isEmpty, !isSuppressed else { return }
        current = queue.removeFirst()
    }

    func dismissCurrent() {
        current = nil
        // The next one (rare, but possible after a border-hopping day)
        // waits for its own foreground moment rather than chaining.
    }

    private var isSuppressed: Bool {
        guard UserDefaults.standard.bool(forKey: "onboardingDone") else { return true }
        let container = AppContainer.shared
        if container.backfillEngine.progress.isRunning { return true }
        if container.importEngine.timelineProgress.isRunning { return true }
        if container.importEngine.flightProgress.isRunning { return true }
        return false
    }
}
