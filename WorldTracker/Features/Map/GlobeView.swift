import MapKit
import SwiftUI
import WorldTrackerKit

/// The cinematic globe: fly-in from space, visited countries burning in
/// aurora with glowing borders, a pulsing home beacon, layered flight arcs,
/// and tap-a-country flyovers. MapKit overlays aren't animatable — all the
/// motion lives in the camera, the beacon annotation, and the card.
struct GlobeView: View {
    let shapes: WorldMapShapes

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCode: String?
    @State private var didFlyIn = false

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let _ = store.changeToken
        let visited = visitedDays
        let maxDays = visited.values.max() ?? 1
        let home = store.homeCountry ?? store.currentStay()?.countryCode
        let homeCenter = home.flatMap { shapes.centroid(forCountry: $0) }

        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $position) {
                    fills(visited: visited, maxDays: maxDays, home: home)
                    borders(visited: visited, maxDays: maxDays, home: home)
                    arcs(visited: visited, home: home, homeCenter: homeCenter)
                    beacon(homeCenter: homeCenter)
                }
                .mapStyle(.imagery(elevation: .realistic))
                .onTapGesture { screenPoint in
                    handleTap(screenPoint, proxy: proxy, visited: visited, homeCenter: homeCenter)
                }
            }
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                if let selectedCode {
                    GlobeSelectionCard(
                        code: selectedCode,
                        isHome: selectedCode == home,
                        onClose: { deselect(homeCenter: homeCenter) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                statsPill
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
            .animation(.spring(duration: 0.35), value: selectedCode)
        }
        .task { await flyIn(homeCenter: homeCenter) }
    }

    // MARK: - Map content (small builders: the type-checker thanks us)

    private func coords(_ ring: [GeoPoint]) -> [CLLocationCoordinate2D] {
        ring.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    @MapContentBuilder
    private func fills(visited: [String: Int], maxDays: Int, home: String?) -> some MapContent {
        ForEach(Array(visited.keys), id: \.self) { code in
            let isHome = code == home
            let ratio = Double(visited[code] ?? 0) / Double(maxDays)
            let fillColor: Color = isHome
                ? Theme.amber.opacity(0.60)
                : Theme.aurora1.opacity(0.50 + 0.35 * ratio)
            ForEach(Array(shapes.rings(forCountry: code).enumerated()), id: \.offset) { _, ring in
                MapPolygon(coordinates: coords(ring))
                    .foregroundStyle(fillColor)
            }
        }
    }

    @MapContentBuilder
    private func borders(visited: [String: Int], maxDays: Int, home: String?) -> some MapContent {
        ForEach(Array(visited.keys), id: \.self) { code in
            let isHome = code == home
            let isSelected = code == selectedCode
            let ratio = Double(visited[code] ?? 0) / Double(maxDays)
            let base: Color = isHome ? Theme.amber : Theme.aurora1
            // Overlay budget: barely-visited countries skip the glow pass.
            let withGlow = isSelected || isHome || ratio >= 0.15
            ForEach(Array(shapes.rings(forCountry: code).enumerated()), id: \.offset) { _, ring in
                let line = coords(ring)
                if withGlow {
                    MapPolyline(coordinates: line)
                        .stroke(base.opacity(0.35), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
                MapPolyline(coordinates: line)
                    .stroke(
                        (isSelected ? Theme.amber : base).opacity(0.9),
                        style: StrokeStyle(lineWidth: isSelected ? 2.5 : 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    @MapContentBuilder
    private func arcs(visited: [String: Int], home: String?, homeCenter: GeoPoint?) -> some MapContent {
        if let homeCenter, let home {
            ForEach(Array(visited.keys.filter { $0 != home }.sorted().prefix(14)), id: \.self) { code in
                if let target = shapes.centroid(forCountry: code) {
                    let line = greatCircleArc(from: homeCenter, to: target, samples: 48)
                        .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    MapPolyline(coordinates: line)
                        .stroke(Theme.aurora2.opacity(0.30), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    MapPolyline(coordinates: line)
                        .stroke(Theme.aurora2.opacity(0.95), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
    }

    @MapContentBuilder
    private func beacon(homeCenter: GeoPoint?) -> some MapContent {
        if let homeCenter {
            Annotation(
                "",
                coordinate: CLLocationCoordinate2D(
                    latitude: homeCenter.latitude, longitude: homeCenter.longitude
                )
            ) {
                HomeBeacon()
            }
            .annotationTitles(.hidden)
        }
    }

    // MARK: - Data

    private var visitedDays: [String: Int] {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        return store.stats(in: earliest...today).daysPerCountry
    }

    private var statsPill: some View {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let stats = store.stats(in: earliest...today)
        let percent = Int((Double(stats.countriesVisited) / 195.0 * 100).rounded())

        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text("\(stats.countriesVisited) countries")
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.ink)
                Text("·").foregroundStyle(Theme.ink3)
                Text("\(percent)% of the world")
                    .foregroundStyle(Theme.ink2)
            }
            .font(.system(size: 13))
            HStack(spacing: 6) {
                Text("\(stats.travelDays) travel days")
                Text("·").foregroundStyle(Theme.ink3)
                Text("\(stats.borderCrossings) crossings")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline2, lineWidth: 1))
    }

    // MARK: - Camera + tap

    private func flyIn(homeCenter: GeoPoint?) async {
        guard !didFlyIn else { return }
        didFlyIn = true
        let center = homeCenter ?? GeoPoint(latitude: 30, longitude: 0)
        let coordinate = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)

        if reduceMotion {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: 28_000_000))
            return
        }
        position = .camera(MapCamera(centerCoordinate: coordinate, distance: 60_000_000))
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.easeInOut(duration: 1.6)) {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: 25_000_000))
        }
    }

    private func handleTap(
        _ point: CGPoint, proxy: MapProxy,
        visited: [String: Int], homeCenter: GeoPoint?
    ) {
        guard let coordinate = proxy.convert(point, from: .local) else { return }
        Task {
            guard let lookup = try? await AppContainer.shared.geoProvider.lookup() else { return }
            let resolved = lookup.resolve(
                GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ).countryCode
            await MainActor.run {
                if let resolved, visited[resolved] != nil {
                    select(resolved)
                } else {
                    deselect(homeCenter: homeCenter)
                }
            }
        }
    }

    private func select(_ code: String) {
        guard let centroid = shapes.centroid(forCountry: code) else { return }
        selectedCode = code
        HapticsDirector.shared.tick()
        withAnimation(.easeInOut(duration: 0.9)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(
                        latitude: centroid.latitude, longitude: centroid.longitude
                    ),
                    distance: flyoverDistance(for: code)
                )
            )
        }
    }

    private func deselect(homeCenter: GeoPoint?) {
        guard selectedCode != nil else { return }
        selectedCode = nil
        let center = homeCenter ?? GeoPoint(latitude: 30, longitude: 0)
        withAnimation(.easeInOut(duration: 0.9)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(
                        latitude: center.latitude, longitude: center.longitude
                    ),
                    distance: 25_000_000
                )
            )
        }
    }

    /// Camera distance scaled to the country's footprint.
    private func flyoverDistance(for code: String) -> Double {
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for ring in shapes.rings(forCountry: code) {
            for point in ring {
                minLat = min(minLat, point.latitude)
                maxLat = max(maxLat, point.latitude)
                minLon = min(minLon, point.longitude)
                maxLon = max(maxLon, point.longitude)
            }
        }
        let span = max(maxLat - minLat, (maxLon - minLon) * 0.7)
        // ~111 km per degree; ×3 padding so the country sits comfortably.
        let distance = span * 111_000 * 3.2
        return min(12_000_000, max(1_600_000, distance))
    }
}

// MARK: - Home beacon

/// Pulsing amber beacon over the home centroid.
private struct HomeBeacon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                dot
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2.4) / 2.4
                    ZStack {
                        Circle()
                            .strokeBorder(Theme.amber.opacity(0.7 * (1 - phase)), lineWidth: 1.5)
                            .frame(width: 14 + 30 * phase, height: 14 + 30 * phase)
                        Circle()
                            .strokeBorder(
                                Theme.amber.opacity(0.7 * (1 - shifted(phase))),
                                lineWidth: 1.5
                            )
                            .frame(width: 14 + 30 * shifted(phase), height: 14 + 30 * shifted(phase))
                        dot
                    }
                    .frame(width: 46, height: 46)
                }
            }
        }
    }

    private func shifted(_ phase: Double) -> Double {
        (phase + 0.5).truncatingRemainder(dividingBy: 1)
    }

    private var dot: some View {
        Circle()
            .fill(Theme.amber)
            .frame(width: 10, height: 10)
            .shadow(color: Theme.amber.opacity(0.9), radius: 6)
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Selection card

/// Floating stat card for the tapped country.
private struct GlobeSelectionCard: View {
    let code: String
    let isHome: Bool
    let onClose: () -> Void

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let lifetimeDays = store.stats(in: earliest...today).daysPerCountry[code] ?? 0
        let trips = store.tripSegments(in: earliest...today)
            .filter { $0.countryCode == code }.count
        let thisYear = store.daysThisYear(in: code)

        HStack(spacing: 12) {
            FlagChip(code: code, size: 44)
                .shadow(color: Theme.aurora1.opacity(0.4), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(countryName(code))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if isHome {
                        Text("HOME")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.amber)
                    }
                }
                Text("\(lifetimeDays)d overall · \(thisYear)d this year · \(trips) \(trips == 1 ? "trip" : "trips")")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            NavigationLink(value: code) {
                Text("Open")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.auroraGradient, in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: 28, height: 28)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline2, lineWidth: 1)
        )
    }
}
