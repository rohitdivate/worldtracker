import CoreLocation
import Foundation
import MapKit

/// Names pending places using Apple's POI database + reverse geocoding.
/// Deliberately low-volume: serialized, throttled, capped per run, retried
/// on later foregrounds — CLGeocoder has strict fair-use limits.
@MainActor
final class PlaceNamer {
    private let engine: PlacesEngine
    private let geocoder = CLGeocoder()
    private var isRunning = false

    private static let perRunCap = 12
    private static let interRequestDelay: UInt64 = 1_200_000_000  // 1.2s

    init(engine: PlacesEngine) {
        self.engine = engine
    }

    /// Called on app foreground: name up to `perRunCap` pending places.
    func processPending() {
        guard !isRunning else { return }
        isRunning = true

        Task { [self] in
            defer { isRunning = false }
            let pending = await engine.pendingNaming(limit: Self.perRunCap)
            for place in pending {
                await name(place)
                try? await Task.sleep(nanoseconds: Self.interRequestDelay)
            }
        }
    }

    private func name(_ place: PlaceSnapshot) async {
        let coordinate = CLLocationCoordinate2D(
            latitude: place.latitude,
            longitude: place.longitude
        )

        // 1. Nearest point of interest within ~100m.
        var poiName: String?
        var poiCategory: String?
        let request = MKLocalPointsOfInterestRequest(
            coordinateRegion: MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            )
        )
        if let response = try? await MKLocalSearch(request: request).start() {
            let origin = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let best = response.mapItems
                .compactMap { item -> (MKMapItem, CLLocationDistance)? in
                    guard let loc = item.placemark.location else { return nil }
                    return (item, loc.distance(from: origin))
                }
                .filter { $0.1 <= 100 }
                .min { $0.1 < $1.1 }
            if let (item, _) = best {
                poiName = item.name
                poiCategory = item.pointOfInterestCategory?.rawValue
            }
        }

        // 2. Reverse geocode for the neighborhood/area.
        var subLocality: String?
        var city: String?
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            subLocality = placemark.subLocality
            city = placemark.locality
        }

        if poiName != nil || subLocality != nil || city != nil {
            await engine.applyName(
                placeID: place.id,
                name: poiName,
                categoryRaw: poiCategory,
                subLocality: subLocality,
                city: city
            )
            NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
        } else {
            await engine.markNamingFailed(placeID: place.id)
        }
    }
}

/// Category → emoji + label for the UI.
enum PlaceCategoryStyle {
    static func emoji(_ categoryRaw: String?) -> String {
        guard let raw = categoryRaw else { return "📍" }
        let category = MKPointOfInterestCategory(rawValue: raw)
        switch category {
        case .museum: return "🏛️"
        case .park, .nationalPark: return "🌳"
        case .cafe: return "☕"
        case .restaurant, .bakery: return "🍜"
        case .store, .foodMarket: return "🛍️"
        case .hotel: return "🛏️"
        case .airport: return "✈️"
        case .beach: return "🏖️"
        case .stadium: return "🏟️"
        case .theater, .movieTheater: return "🎭"
        case .library: return "📚"
        case .brewery, .winery, .nightlife: return "🍷"
        case .fitnessCenter: return "🏋️"
        case .campground: return "⛺"
        case .zoo, .aquarium: return "🦁"
        case .amusementPark: return "🎢"
        case .university, .school: return "🎓"
        case .publicTransport: return "🚉"
        case .marina: return "⛵"
        case .castle, .fortress, .landmark: return "🏰"
        default: return "📍"
        }
    }

    static func label(_ categoryRaw: String?) -> String {
        guard let raw = categoryRaw else { return "Place" }
        // "MKPOICategoryMuseum" → "Museum"
        let trimmed = raw.replacingOccurrences(of: "MKPOICategory", with: "")
        var out = ""
        for ch in trimmed {
            if ch.isUppercase, !out.isEmpty { out.append(" ") }
            out.append(ch)
        }
        return out.isEmpty ? "Place" : out
    }
}
