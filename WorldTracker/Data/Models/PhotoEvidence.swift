import Foundation
import SwiftData

/// Aggregated photo evidence: one row per (day, ~1km cell) — NOT one per
/// photo, so 50k photos become a few thousand rows and CloudKit stays sane.
/// The full photo set is always re-derivable from the library.
@Model
final class PhotoEvidence {
    var id: UUID = UUID()
    var epochDay: Int = 0
    /// Cell-rounded coordinates (2 decimals ≈ 1.1 km).
    var latitude: Double = 0
    var longitude: Double = 0
    var photoCount: Int = 1
    /// PHAsset.localIdentifier of one representative photo (for evidence UI).
    var representativeAssetID: String?
    var countryCode: String?
    var city: String?
    var timeZoneID: String?

    init(
        epochDay: Int,
        latitude: Double,
        longitude: Double,
        photoCount: Int,
        representativeAssetID: String?,
        countryCode: String?,
        city: String?,
        timeZoneID: String?
    ) {
        self.id = UUID()
        self.epochDay = epochDay
        self.latitude = latitude
        self.longitude = longitude
        self.photoCount = photoCount
        self.representativeAssetID = representativeAssetID
        self.countryCode = countryCode
        self.city = city
        self.timeZoneID = timeZoneID
    }
}

/// Local-only: state of the last photo scan.
@Model
final class BackfillCheckpoint {
    var id: UUID = UUID()
    /// idle | running | done | failed
    var statusRaw: String = "idle"
    var processedCount: Int = 0
    var totalCount: Int = 0
    var reconstructedDays: Int = 0
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.updatedAt = Date()
    }
}
