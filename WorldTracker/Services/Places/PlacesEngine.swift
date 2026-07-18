import Foundation
import SwiftData
import WorldTrackerKit

/// Sendable UI snapshots.
struct PlaceSnapshot: Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let categoryRaw: String?
    let latitude: Double
    let longitude: Double
    let countryCode: String?
    let city: String?
    let subLocality: String?
    let sourceRaw: String
    let isNamePending: Bool
    let visitCount: Int
    let lastVisit: Date?
    let firstVisit: Date?
}

struct VisitSnapshot: Identifiable, Sendable {
    let id: UUID
    let arrival: Date?
    let departure: Date?
    let epochDay: Int
    let sourceRaw: String
    let assetIDs: [String]
}

/// Match-or-create place records from visit events and photo clusters.
@ModelActor
actor PlacesEngine {
    // MARK: - Live visits

    func ingestVisit(
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        arrival: Date?,
        departure: Date?,
        lookup: GeoLookup
    ) {
        let point = GeoPoint(latitude: latitude, longitude: longitude)
        let res = lookup.resolve(point)
        let tz = res.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current
        let anchor = departure ?? arrival ?? Date()
        let day = EpochDay(date: anchor, timeZone: tz).value

        let place = matchOrCreate(
            latitude: latitude,
            longitude: longitude,
            matchRadius: max(75, accuracy),
            resolution: res,
            sourceRaw: "visit"
        )

        // Skip duplicate delivery of the same visit window.
        let existing = (place.visits ?? []).contains {
            $0.epochDay == day && abs(($0.arrival ?? .distantPast).timeIntervalSince(arrival ?? .distantPast)) < 60
        }
        guard !existing else { return }

        let visit = PlaceVisit(
            arrival: arrival,
            departure: departure,
            epochDay: day,
            latitude: latitude,
            longitude: longitude,
            sourceRaw: "visit"
        )
        visit.place = place
        modelContext.insert(visit)
        try? modelContext.save()
    }

    // MARK: - Photo clusters (backfill)

    func createPhotoPlaces(clusters: [PhotoCluster], lookup: GeoLookup) {
        // Photo re-syncs replace photo-derived places that have no live visits.
        cleanupPhotoPlaces()

        // Largest clusters first; cap per run to keep naming budgets sane.
        let ranked = clusters.sorted { $0.assetIDs.count > $1.assetIDs.count }.prefix(400)

        for cluster in ranked {
            let res = lookup.resolve(cluster.center)
            let tz = res.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current
            let day = EpochDay(date: cluster.start, timeZone: tz).value

            let place = matchOrCreate(
                latitude: cluster.center.latitude,
                longitude: cluster.center.longitude,
                matchRadius: 120,
                resolution: res,
                sourceRaw: "photo"
            )

            let duplicate = (place.visits ?? []).contains {
                $0.epochDay == day && $0.sourceRaw == "photo"
            }
            guard !duplicate else { continue }

            let visit = PlaceVisit(
                arrival: cluster.start,
                departure: cluster.end,
                epochDay: day,
                latitude: cluster.center.latitude,
                longitude: cluster.center.longitude,
                sourceRaw: "photo",
                assetIDsJoined: cluster.assetIDs.prefix(12).joined(separator: ",")
            )
            visit.place = place
            modelContext.insert(visit)
        }
        try? modelContext.save()
    }

    /// Remove photo-sourced places that have no live-visit corroboration
    /// (called before a photo re-sync repopulates them).
    private func cleanupPhotoPlaces() {
        let photo = "photo"
        let predicate = #Predicate<Place> { $0.sourceRaw == photo }
        let places = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        for place in places {
            let hasLiveVisits = (place.visits ?? []).contains { $0.sourceRaw == "visit" }
            if !hasLiveVisits {
                modelContext.delete(place)
            }
        }
    }

    // MARK: - Matching

    private func matchOrCreate(
        latitude: Double,
        longitude: Double,
        matchRadius: Double,
        resolution: GeoResolution,
        sourceRaw: String
    ) -> Place {
        // Cheap bbox prefilter (~600m) then true distance match.
        let latDelta = 0.006
        let lonDelta = 0.009
        let minLat = latitude - latDelta
        let maxLat = latitude + latDelta
        let minLon = longitude - lonDelta
        let maxLon = longitude + lonDelta
        let predicate = #Predicate<Place> {
            $0.latitude >= minLat && $0.latitude <= maxLat
                && $0.longitude >= minLon && $0.longitude <= maxLon
        }
        let nearby = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []

        let point = GeoPoint(latitude: latitude, longitude: longitude)
        var best: (Place, Double)?
        for place in nearby {
            let d = Haversine.meters(
                from: point,
                to: GeoPoint(latitude: place.latitude, longitude: place.longitude)
            )
            let limit = max(place.radius, matchRadius)
            if d <= limit, d < (best?.1 ?? .infinity) {
                best = (place, d)
            }
        }
        if let (place, _) = best { return place }

        let fallbackName = [resolution.admin1 == resolution.cityName ? nil : resolution.admin1,
                            resolution.cityName]
            .compactMap { $0 }
            .first ?? "Unknown place"
        let place = Place(
            name: fallbackName,
            latitude: latitude,
            longitude: longitude,
            radius: max(75, matchRadius),
            countryCode: resolution.countryCode,
            city: resolution.cityName,
            subLocality: nil,
            sourceRaw: sourceRaw,
            isNamePending: true
        )
        modelContext.insert(place)
        return place
    }

    // MARK: - Naming support

    func pendingNaming(limit: Int) -> [PlaceSnapshot] {
        let predicate = #Predicate<Place> { $0.isNamePending }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = limit
        return ((try? modelContext.fetch(descriptor)) ?? []).map(snapshot)
    }

    func applyName(
        placeID: UUID,
        name: String?,
        categoryRaw: String?,
        subLocality: String?,
        city: String?
    ) {
        guard let place = fetch(placeID) else { return }
        if let name, !name.isEmpty {
            place.name = name
        } else if let subLocality, let cityName = place.city ?? city {
            place.name = "\(subLocality), \(cityName)"
        }
        place.categoryRaw = categoryRaw ?? place.categoryRaw
        place.subLocality = subLocality ?? place.subLocality
        if let city { place.city = place.city ?? city }
        place.isNamePending = false
        try? modelContext.save()
    }

    func markNamingFailed(placeID: UUID) {
        // Leave pending so a later foreground retries (offline, throttled…).
        _ = placeID
    }

    // MARK: - UI queries

    func allPlaces() -> [PlaceSnapshot] {
        let places = (try? modelContext.fetch(FetchDescriptor<Place>())) ?? []
        return places
            .map(snapshot)
            .filter { $0.visitCount > 0 }
            .sorted { ($0.lastVisit ?? .distantPast) > ($1.lastVisit ?? .distantPast) }
    }

    func visits(for placeID: UUID) -> [VisitSnapshot] {
        guard let place = fetch(placeID) else { return [] }
        return (place.visits ?? [])
            .sorted { ($0.arrival ?? .distantPast) > ($1.arrival ?? .distantPast) }
            .map {
                VisitSnapshot(
                    id: $0.id,
                    arrival: $0.arrival,
                    departure: $0.departure,
                    epochDay: $0.epochDay,
                    sourceRaw: $0.sourceRaw,
                    assetIDs: $0.assetIDsJoined?.split(separator: ",").map(String.init) ?? []
                )
            }
    }

    func rename(placeID: UUID, to name: String) {
        guard let place = fetch(placeID) else { return }
        place.name = name
        place.isNamePending = false
        try? modelContext.save()
    }

    func delete(placeID: UUID) {
        guard let place = fetch(placeID) else { return }
        modelContext.delete(place)
        try? modelContext.save()
    }

    private func fetch(_ id: UUID) -> Place? {
        let predicate = #Predicate<Place> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func snapshot(_ place: Place) -> PlaceSnapshot {
        let visits = place.visits ?? []
        return PlaceSnapshot(
            id: place.id,
            name: place.name,
            categoryRaw: place.categoryRaw,
            latitude: place.latitude,
            longitude: place.longitude,
            countryCode: place.countryCode,
            city: place.city,
            subLocality: place.subLocality,
            sourceRaw: place.sourceRaw,
            isNamePending: place.isNamePending,
            visitCount: visits.count,
            lastVisit: visits.compactMap { $0.arrival ?? $0.departure }.max(),
            firstVisit: visits.compactMap { $0.arrival ?? $0.departure }.min()
        )
    }
}
