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
            PhotoEvidence.self,
            Place.self,
            PlaceVisit.self,
        ])
        let localSchema = Schema([
            LocationSample.self,
            BackfillCheckpoint.self,
        ])

        // Private-iCloud backup. Applied at launch; if the CloudKit container
        // is unavailable (capability not yet added in Xcode, signed out of
        // iCloud), fall back to local-only rather than failing to launch.
        let wantsCloud = UserDefaults.standard.bool(forKey: "icloudBackup")

        let synced = ModelConfiguration(
            "Synced",
            schema: syncedSchema,
            cloudKitDatabase: wantsCloud ? .automatic : .none
        )
        let local = ModelConfiguration(
            "Local",
            schema: localSchema,
            cloudKitDatabase: .none
        )

        let allSchema = Schema([
            CountryDayFact.self,
            DayAnnotation.self,
            PhotoEvidence.self,
            Place.self,
            PlaceVisit.self,
            LocationSample.self,
            BackfillCheckpoint.self,
        ])
        do {
            return try ModelContainer(
                for: allSchema,
                migrationPlan: WorldTrackerMigrationPlan.self,
                configurations: [synced, local]
            )
        } catch where wantsCloud {
            // CloudKit unavailable — run local-only and surface it in Settings.
            UserDefaults.standard.set(false, forKey: "icloudBackup")
            UserDefaults.standard.set(true, forKey: "icloudBackupFellBack")
            let localSynced = ModelConfiguration(
                "Synced",
                schema: syncedSchema,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: allSchema,
                migrationPlan: WorldTrackerMigrationPlan.self,
                configurations: [localSynced, local]
            )
        }
    }
}

enum WorldTrackerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [CountryDayFact.self, DayAnnotation.self, PhotoEvidence.self,
         Place.self, PlaceVisit.self,
         LocationSample.self, BackfillCheckpoint.self]
    }
}

enum WorldTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WorldTrackerSchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
}
