import Foundation
import SwiftData
import WorldTrackerKit

/// Loads the offline atlas exactly once, off the main thread, and hands out
/// the shared instance.
actor GeoLookupProvider {
    private var cached: GeoLookup?

    func lookup() throws -> GeoLookup {
        if let cached { return cached }
        let lookup = try GeoLookup()
        cached = lookup
        return lookup
    }
}

/// Composition root. Created once in AppDelegate before the SwiftUI scene
/// exists, so background location relaunches always have a full stack.
@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let modelContainer: ModelContainer
    let geoProvider: GeoLookupProvider
    let ingestor: LocationIngestor
    let locationService: LocationService

    private init() {
        do {
            modelContainer = try AppDatabase.makeContainer()
        } catch {
            // A broken store on first run is unrecoverable dev-time state;
            // fall back to in-memory so the app still opens and can report.
            let schema = Schema([CountryDayFact.self, DayAnnotation.self, LocationSample.self])
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: schema, configurations: [memory])
        }
        geoProvider = GeoLookupProvider()
        ingestor = LocationIngestor(modelContainer: modelContainer)
        locationService = LocationService(ingestor: ingestor, lookup: geoProvider)

        // Warm the atlas so first lookups don't pay the load cost.
        let provider = geoProvider
        Task.detached(priority: .utility) {
            _ = try? await provider.lookup()
        }
    }
}
