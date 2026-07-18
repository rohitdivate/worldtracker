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
    let ledgerStore: LedgerStore
    let backfillEngine: PhotoBackfillEngine
    let editService: EditService
    let placesEngine: PlacesEngine
    let placeNamer: PlaceNamer
    let exportService: ExportService
    let importEngine: ImportEngine
    let wrappedBuilder: YearInReviewBuilder
    let celebrationCoordinator = CelebrationCoordinator()
    let router = AppRouter()
    let setupChecklist = SetupChecklist()

    private init() {
        do {
            modelContainer = try AppDatabase.makeContainer()
        } catch {
            // A broken store on first run is unrecoverable dev-time state;
            // fall back to in-memory so the app still opens and can report.
            let schema = Schema([
                CountryDayFact.self, DayAnnotation.self, PhotoEvidence.self,
                Place.self, PlaceVisit.self,
                LocationSample.self, BackfillCheckpoint.self, ImportCheckpoint.self,
            ])
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: schema, configurations: [memory])
        }
        geoProvider = GeoLookupProvider()
        ingestor = LocationIngestor(modelContainer: modelContainer)
        placesEngine = PlacesEngine(modelContainer: modelContainer)
        locationService = LocationService(ingestor: ingestor, lookup: geoProvider, places: placesEngine)
        placeNamer = PlaceNamer(engine: placesEngine)
        ledgerStore = LedgerStore(container: modelContainer)
        backfillEngine = PhotoBackfillEngine(container: modelContainer, geoProvider: geoProvider, places: placesEngine)
        editService = EditService(container: modelContainer)
        exportService = ExportService(store: ledgerStore)
        importEngine = ImportEngine(container: modelContainer, geoProvider: geoProvider)
        wrappedBuilder = YearInReviewBuilder(
            store: ledgerStore, container: modelContainer, placesEngine: placesEngine
        )

        // Warm the atlas so first lookups don't pay the load cost.
        let provider = geoProvider
        Task.detached(priority: .utility) {
            _ = try? await provider.lookup()
        }

        // A crash or eviction mid-backfill leaves a live checkpoint behind;
        // finish an interrupted swap and mark stale scans resumable.
        backfillEngine.recoverIfNeeded()
    }
}
