import CoreLocation
import Foundation
import Observation
import UIKit

/// The tracking engine. Battery-invisible by design:
///  - significant location changes (cell-tower granularity, relaunches the app)
///  - visit monitoring (arrive/depart — also feeds Places from M7)
///  - a one-shot fix on every foregrounding
///  - device-timezone change hints
/// Never continuous GPS, no background location mode.
@Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let ingestor: LocationIngestor
    private let lookup: GeoLookupProvider
    private let places: PlacesEngine

    // Observable health state for the UI.
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    private(set) var backgroundRefreshStatus: UIBackgroundRefreshStatus = .available
    private(set) var lastEvent: Date?
    private(set) var lastEventDescription: String = "—"

    /// User toggle (Settings → Smart tracking).
    var smartTrackingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "smartTracking") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "smartTracking")
            newValue ? startMonitoring() : stopMonitoring()
        }
    }

    init(ingestor: LocationIngestor, lookup: GeoLookupProvider, places: PlacesEngine) {
        self.ingestor = ingestor
        self.lookup = lookup
        self.places = places
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
    }

    // MARK: - Lifecycle

    /// Called on EVERY launch — including background relaunches triggered by a
    /// significant location change. Monitoring does not survive launches
    /// unless restarted here.
    func startMonitoring() {
        guard smartTrackingEnabled else { return }
        guard authorizationStatus == .authorizedAlways
            || authorizationStatus == .authorizedWhenInUse
        else { return }
        manager.startMonitoringSignificantLocationChanges()
        manager.startMonitoringVisits()
    }

    func stopMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
    }

    /// Called from every scene-activation: refresh health, take a one-shot
    /// fix (the "landed and opened the phone" detector), check timezone.
    func onForeground() {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

        if authorizationStatus == .authorizedAlways
            || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
            startMonitoring()
        }

        checkTimezoneChange()
    }

    // MARK: - Permission flow

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysUpgrade() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Internals

    private func checkTimezoneChange() {
        let current = TimeZone.current.identifier
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: "lastKnownTimeZone")
        defaults.set(current, forKey: "lastKnownTimeZone")
        guard let previous, previous != current else { return }

        let ingestor = self.ingestor
        let lookupProvider = self.lookup
        Task.detached(priority: .utility) {
            guard let lookup = try? await lookupProvider.lookup() else { return }
            await ingestor.ingestTimezoneHint(
                timeZoneID: current,
                timestamp: Date(),
                lookup: lookup
            )
        }
    }

    private func ingest(_ location: CLLocation, kind: SampleKind) {
        lastEvent = Date()
        lastEventDescription = "\(kind.rawValue) @ \(location.coordinate.latitude.rounded(to: 3)), \(location.coordinate.longitude.rounded(to: 3))"

        let ingestor = self.ingestor
        let lookupProvider = self.lookup
        Task.detached(priority: .utility) {
            guard let lookup = try? await lookupProvider.lookup() else { return }
            await ingestor.ingest(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                timestamp: location.timestamp,
                kind: kind,
                lookup: lookup
            )
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        if authorizationStatus == .authorizedAlways
            || authorizationStatus == .authorizedWhenInUse {
            startMonitoring()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        // Reject wildly stale or inaccurate fixes (cell-only can be ~km — fine).
        guard latest.horizontalAccuracy >= 0, latest.horizontalAccuracy < 20_000 else { return }
        ingest(latest, kind: .slc)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Departures describe a completed stay — feed the Places pipeline.
        if visit.departureDate != .distantFuture {
            let places = self.places
            let lookupProvider = self.lookup
            let lat = visit.coordinate.latitude
            let lon = visit.coordinate.longitude
            let accuracy = visit.horizontalAccuracy
            let arrival = visit.arrivalDate == .distantPast ? nil : visit.arrivalDate
            let departure = visit.departureDate
            Task.detached(priority: .utility) {
                guard let lookup = try? await lookupProvider.lookup() else { return }
                await places.ingestVisit(
                    latitude: lat,
                    longitude: lon,
                    accuracy: accuracy,
                    arrival: arrival,
                    departure: departure,
                    lookup: lookup
                )
            }
        }

        let isArrival = visit.departureDate == .distantFuture
        let timestamp: Date
        if isArrival {
            timestamp = visit.arrivalDate == .distantPast ? Date() : visit.arrivalDate
        } else {
            timestamp = visit.departureDate
        }
        let location = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: visit.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
        ingest(location, kind: isArrival ? .visitArrive : .visitDepart)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown is transient; everything else is logged via
        // the health screen's "last event" only.
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
