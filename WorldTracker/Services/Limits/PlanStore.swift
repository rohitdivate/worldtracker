import Foundation
import Observation
import WorldTrackerKit

/// Trips that haven't happened yet. Like limit rules these are settings,
/// kept as one Codable blob; the ledger only ever holds what was recorded.
@MainActor
@Observable
final class PlanStore {
    private static let key = "plannedTrips"

    private(set) var plans: [PlannedTrip]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([PlannedTrip].self, from: data) {
            plans = decoded
        } else {
            plans = []
        }
    }

    /// Plans with a future day left in them, soonest first.
    func upcoming(today: Int) -> [PlannedTrip] {
        TripPlans.upcoming(plans, today: today)
    }

    func save(_ plan: PlannedTrip) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        persist()
    }

    func remove(id: String) {
        plans.removeAll { $0.id == id }
        persist()
    }

    /// Drops plans that are entirely in the past: the ledger has those days.
    func prune(today: Int) {
        let kept = plans.filter { $0.endDay > today }
        if kept.count != plans.count {
            plans = kept
            persist()
        }
    }

    /// The future the plans describe, for forecasting.
    func projectedDays(using store: LedgerStore) -> [ResolvedDay] {
        TripPlans.projectedDays(plans: plans, after: store.todayEpoch, home: store.homeCountry)
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(plans), forKey: Self.key)
    }
}
