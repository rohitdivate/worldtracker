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
            ImportCheckpoint.self,
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
            ImportCheckpoint.self,
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

enum WorldTrackerSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [CountryDayFact.self, DayAnnotation.self, PhotoEvidence.self,
         Place.self, PlaceVisit.self,
         LocationSample.self, BackfillCheckpoint.self, ImportCheckpoint.self]
    }
}

/// V3: scanGeneration on CountryDayFact/PhotoEvidence + richer
/// BackfillCheckpoint (generation-swap backfill). Additive, defaulted.
enum WorldTrackerSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [CountryDayFact.self, DayAnnotation.self, PhotoEvidence.self,
         Place.self, PlaceVisit.self,
         LocationSample.self, BackfillCheckpoint.self, ImportCheckpoint.self]
    }
}

enum WorldTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WorldTrackerSchemaV1.self, WorldTrackerSchemaV2.self, WorldTrackerSchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(
                fromVersion: WorldTrackerSchemaV1.self,
                toVersion: WorldTrackerSchemaV2.self
            ),
            MigrationStage.lightweight(
                fromVersion: WorldTrackerSchemaV2.self,
                toVersion: WorldTrackerSchemaV3.self
            ),
        ]
    }
}
