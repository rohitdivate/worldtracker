import MapKit
import SwiftUI
import WorldTrackerKit

/// Your world: a realistic globe with every visited country lit in aurora
/// tones and great-circle flight arcs radiating from home.
struct WorldMapView: View {
    @State private var shapes: WorldMapShapes?
    @State private var mode: Mode = .globe
    @State private var position: MapCameraPosition = .automatic

    enum Mode: String, CaseIterable {
        case globe = "Globe"
        case countries = "Countries"
    }

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let _ = store.changeToken
        NavigationStack {
            ZStack {
                Theme.sky.ignoresSafeArea()

                if mode == .globe {
                    globe
                } else {
                    countriesList
                }
            }
            .navigationTitle("Your world")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
            }
            .navigationDestination(for: String.self) { code in
                CountryDetailView(countryCode: code)
            }
            .task {
                if shapes == nil {
                    shapes = try? await Task.detached { try WorldMapShapes() }.value
                }
                setInitialCamera()
            }
        }
    }

    // MARK: - Globe

    private var visitedDays: [String: Int] {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        return store.stats(in: earliest...today).daysPerCountry
    }

    private var globe: some View {
        let visited = visitedDays
        let maxDays = visited.values.max() ?? 1
        let home = store.homeCountry ?? store.currentStay()?.countryCode
        let homeCenter = home.flatMap { shapes?.centroid(forCountry: $0) }

        return ZStack(alignment: .bottom) {
            Map(position: $position) {
                if let shapes {
                    // Visited countries, shaded by time spent.
                    ForEach(Array(visited.keys), id: \.self) { code in
                        let isHome = code == home
                        let intensity = 0.25 + 0.5 * Double(visited[code] ?? 0) / Double(maxDays)
                        ForEach(Array(shapes.rings(forCountry: code).enumerated()), id: \.offset) { _, ring in
                            MapPolygon(coordinates: ring.map {
                                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                            })
                            .foregroundStyle(
                                (isHome ? Theme.amber : Theme.aurora1)
                                    .opacity(isHome ? 0.42 : intensity)
                            )
                        }
                    }

                    // Flight arcs: home → the countries you've visited.
                    if let homeCenter, let home {
                        ForEach(Array(visited.keys.filter { $0 != home }.prefix(14)), id: \.self) { code in
                            if let target = shapes.centroid(forCountry: code) {
                                MapPolyline(coordinates: greatCircleArc(from: homeCenter, to: target).map {
                                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                                })
                                .stroke(
                                    Theme.aurora2.opacity(0.75),
                                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 5])
                                )
                            }
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)

            statsPill
                .padding(.bottom, 96)
        }
    }

    private var statsPill: some View {
        let visited = visitedDays
        let percent = Int((Double(visited.count) / 195.0 * 100).rounded())
        return HStack(spacing: 6) {
            Text("\(visited.count) countries")
                .fontWeight(.bold)
                .foregroundStyle(Theme.ink)
            Text("·").foregroundStyle(Theme.ink3)
            Text("\(percent)% of the world")
                .foregroundStyle(Theme.ink2)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline2, lineWidth: 1))
    }

    private func setInitialCamera() {
        let home = store.homeCountry ?? store.currentStay()?.countryCode
        let center = home.flatMap { shapes?.centroid(forCountry: $0) }
            ?? GeoPoint(latitude: 30, longitude: 0)
        position = .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: center.latitude,
                    longitude: center.longitude
                ),
                distance: 28_000_000
            )
        )
    }

    // MARK: - Countries list

    private var countriesList: some View {
        let visited = visitedDays
        let ranked = visited.sorted { ($0.value, $1.key) > ($1.value, $0.key) }

        return ScrollView {
            LazyVStack(spacing: 8) {
                if ranked.isEmpty {
                    Text("Your world lights up as tracking and photo history fill in.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 60)
                }
                ForEach(ranked, id: \.key) { code, days in
                    NavigationLink(value: code) {
                        HStack(spacing: 12) {
                            FlagChip(code: code, size: 36)
                            Text(countryName(code))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            if code == store.homeCountry {
                                Text("HOME")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Theme.amber)
                            }
                            Spacer()
                            Text("\(days)d")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.aurora1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.ink3)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .nightCard()
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

#Preview {
    WorldMapView()
        .preferredColorScheme(.dark)
}
