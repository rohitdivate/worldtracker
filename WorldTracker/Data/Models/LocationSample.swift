import Foundation
import SwiftData

/// Sparse audit trail of location events (LOCAL-ONLY store — never synced).
/// This is evidence for the ledger and the Tracking Health screen, not a
/// continuous GPS track: significant-change events arrive at cell-tower
/// granularity, a handful of times per day.
@Model
final class LocationSample {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    var horizontalAccuracy: Double = 0
    /// SampleKind.rawValue: slc | visitArrive | visitDepart | foreground | launch
    var kindRaw: String = "slc"
    var countryCode: String?
    var city: String?
    var timeZoneID: String?
    /// Day bucket computed with the COORDINATE's timezone.
    var epochDay: Int = 0

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        kindRaw: String,
        countryCode: String?,
        city: String?,
        timeZoneID: String?,
        epochDay: Int
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.kindRaw = kindRaw
        self.countryCode = countryCode
        self.city = city
        self.timeZoneID = timeZoneID
        self.epochDay = epochDay
    }
}

enum SampleKind: String {
    case slc
    case visitArrive
    case visitDepart
    case foreground
    case launch
}
