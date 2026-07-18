import Foundation
import Observation

/// Decides when a "new country" moment is actually shown.
/// Detection happens at the live-ingest write (DB-truth); this class owns
/// queuing, suppression, and dedupe so the moment lands exactly once, in the
/// foreground, never on top of onboarding or a running backfill/import.
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

    private(set) var current: Celebration?
    private var queue: [Celebration] = []

    /// Called from the ingest path (already deduped by the DB-truth check;
    /// this second layer guards against edits that delete and re-create).
    func newCountryDetected(code: String, number: Int, city: String?) {
        let key = "celebrated-\(code)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        queue.append(Celebration(countryCode: code, number: number, city: city))
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
