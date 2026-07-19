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
        // NO explicit migration plan — and that's load-bearing. Every schema
        // change this app makes is additive with defaults, which SwiftData
        // migrates automatically. The previous VersionedSchema plan pointed
        // V1/V2/V3 at the SAME live model classes, so adding scanGeneration
        // in v4 silently mutated what "V1" and "V2" described: an on-disk V2
        // store no longer matched any version in the plan, and staged
        // migration died with an uncatchable exception at launch (black
        // screen). Automatic lightweight migration has no version table to
        // disagree with. If a change ever needs a custom migration stage,
        // the old schemas must be frozen COPIES of the models, not aliases.
        do {
            return try ModelContainer(
                for: allSchema,
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
                configurations: [localSynced, local]
            )
        }
    }
}
