import SwiftUI
import WorldTrackerKit

/// Your world: the upgraded globe (dark vector earth, aurora glow, day-count
/// chips) plus the numbers view — a ranked day-count ledger.
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
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let stats = store.stats(in: earliest...today)
        let ranked = stats.daysPerCountry.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
        let home = store.homeCountry

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
                    ScrollView {
                        VStack(spacing: 14) {
                            ledger(ranked: ranked, home: home, today: today, earliest: earliest)
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
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

    // MARK: - The ledger

    private func ledger(
        ranked: [(key: String, value: Int)], home: String?, today: Int, earliest: Int
    ) -> some View {
        let maxDays = ranked.first?.value ?? 1
        let segmentsByCountry = Dictionary(
            grouping: store.segments(in: earliest...today), by: \.countryCode
        )

        return VStack(spacing: 9) {
            if ranked.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.auroraGradient)
                    Text("Your constellation lights up as tracking and photo history fill in.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink3)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            }

            ForEach(ranked, id: \.key) { code, days in
                NavigationLink(value: code) {
                    countryCard(
                        code: code,
                        days: days,
                        maxDays: maxDays,
                        isHome: code == home,
                        segments: segmentsByCountry[code] ?? [],
                        today: today
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func countryCard(
        code: String, days: Int, maxDays: Int, isHome: Bool,
        segments: [TripSegment], today: Int
    ) -> some View {
        HStack(spacing: 12) {
            Text(flagEmoji(code)).font(.system(size: 26))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(countryName(code))
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if isHome {
                        Text("HOME")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.amber)
                    }
                }
                Capsule()
                    .fill(Theme.hairline)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Theme.auroraGradient)
                                .frame(width: max(4, geo.size.width * CGFloat(days) / CGFloat(maxDays)))
                        }
                    }
                    .frame(width: 132, height: 3)
                Text(subtitle(code: code, isHome: isHome, segments: segments, today: today))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(days)")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(isHome ? Theme.amber : Theme.aurora1)
                    .contentTransition(.numericText())
                Text("DAYS")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.ink3)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .nightCard()
    }

    private func subtitle(
        code: String, isHome: Bool, segments: [TripSegment], today: Int
    ) -> String {
        if isHome, let start = store.homeTimeline.periods.last?.startDay {
            let (year, month, _) = EpochDay(value: start).civil()
            let months = DateFormatter().shortMonthSymbols ?? []
            if month >= 1, month <= months.count {
                return "Living here since \(months[month - 1]) \(year)"
            }
        }
        let trips = segments.count
        guard trips > 0 else { return isHome ? "Home base" : "Visited" }
        let (todayYear, _, _) = EpochDay(value: today).civil()
        if let last = segments.map(\.endDay).max() {
            if last >= today {
                return "\(trips) \(trips == 1 ? "stay" : "stays") · here now"
            }
            return "\(trips) \(trips == 1 ? "trip" : "trips") · last \(DayFormat.shortRange(last, last, todayYear: todayYear))"
        }
        return "\(trips) \(trips == 1 ? "trip" : "trips")"
    }
}

#Preview {
    WorldMapView()
        .preferredColorScheme(.dark)
}
