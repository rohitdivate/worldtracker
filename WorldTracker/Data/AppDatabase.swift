import Foundation
import SwiftData

/// Builds the app's ModelContainer with two stores:
///  - "Synced": the travel ledger (facts, annotations) — CloudKit-ready,
///    cloud sync flips on in M9 via `cloudKitDatabase: .automatic`.
///  - "Local": device-specific audit data that must never sync.
enum AppDatabase {
    static func makeContainer() throws -> ModelContainer {
        let syncedSchema = Schema([
            CountryDayFact.self,
            DayAnnotation.self,
        ])
        let localSchema = Schema([
            LocationSample.self,
        ])

        let synced = ModelConfiguration(
            "Synced",
            schema: syncedSchema,
            cloudKitDatabase: .none
        )
        let local = ModelConfiguration(
            "Local",
            schema: localSchema,
            cloudKitDatabase: .none
        )

        let allSchema = Schema([
            CountryDayFact.self,
            DayAnnotation.self,
            LocationSample.self,
        ])
        return try ModelContainer(
            for: allSchema,
            migrationPlan: WorldTrackerMigrationPlan.self,
            configurations: [synced, local]
        )
    }
}

enum WorldTrackerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [CountryDayFact.self, DayAnnotation.self, LocationSample.self]
    }
}

enum WorldTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WorldTrackerSchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
}
