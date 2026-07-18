import MapKit
import SwiftUI
import WorldTrackerKit

/// Your world: a realistic globe with every visited country lit in aurora
/// tones and great-circle flight arcs radiating from home.
struct WorldMapView: View {
    @State private var shapes: WorldMapShapes?
    @State private var mode: Mode = .globe

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
                    if let shapes {
                        GlobeView(shapes: shapes)
                    } else {
                        ProgressView().tint(Theme.aurora1)
                    }
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
            .navigationDestination(for: TripSegment.self) { segment in
                TripDetailView(segment: segment)
            }
            .task {
                if shapes == nil {
                    shapes = try? await Task.detached { try WorldMapShapes() }.value
                }
            }
        }
    }

    // MARK: - Countries list

    private var visitedDays: [String: Int] {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        return store.stats(in: earliest...today).daysPerCountry
    }

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
