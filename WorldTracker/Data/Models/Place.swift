import Foundation
import SwiftData

/// A specific place you've spent time: the museum, the market, the café.
/// Created from iOS visit detection (live) and photo clusters (backfill).
/// CloudKit-compatible: defaults everywhere, optional relationships.
@Model
final class Place {
    var id: UUID = UUID()
    /// "Musée d'Orsay", or a fallback like "Soho, London" until named.
    var name: String = ""
    /// MKPointOfInterestCategory.rawValue (nil = unknown/none).
    var categoryRaw: String?
    var latitude: Double = 0
    var longitude: Double = 0
    /// Matching radius in meters.
    var radius: Double = 75
    var countryCode: String?
    var city: String?
    /// Neighborhood/area (CLPlacemark.subLocality) — powers area grouping.
    var subLocality: String?
    /// visit | photo | manual
    var sourceRaw: String = "visit"
    /// Awaiting MapKit/CLGeocoder naming (retried on foregrounds).
    var isNamePending: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PlaceVisit.place)
    var visits: [PlaceVisit]? = []

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        countryCode: String?,
        city: String?,
        subLocality: String?,
        sourceRaw: String,
        isNamePending: Bool
    ) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.countryCode = countryCode
        self.city = city
        self.subLocality = subLocality
        self.sourceRaw = sourceRaw
        self.isNamePending = isNamePending
        self.createdAt = Date()
    }
}

@Model
final class PlaceVisit {
    var id: UUID = UUID()
    var arrival: Date?
    var departure: Date?
    var epochDay: Int = 0
    var latitude: Double = 0
    var longitude: Double = 0
    /// visit | photo
    var sourceRaw: String = "visit"
    /// For photo-derived visits: comma-joined PHAsset localIdentifiers
    /// (capped) so the detail screen can show the photos taken there.
    var assetIDsJoined: String?

    var place: Place?

    init(
        arrival: Date?,
        departure: Date?,
        epochDay: Int,
        latitude: Double,
        longitude: Double,
        sourceRaw: String,
        assetIDsJoined: String? = nil
    ) {
        self.id = UUID()
        self.arrival = arrival
        self.departure = departure
        self.epochDay = epochDay
        self.latitude = latitude
        self.longitude = longitude
        self.sourceRaw = sourceRaw
        self.assetIDsJoined = assetIDsJoined
    }
}
