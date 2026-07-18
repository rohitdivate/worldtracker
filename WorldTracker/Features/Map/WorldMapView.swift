import SwiftUI
import WorldTrackerKit

/// Your world as a constellation: a glanceable dot-matrix world map in pure
/// Night Flight tones (no satellite imagery, ever) with the day-count
/// ledger in the same scroll. Numbers first; the map is the glance.
struct WorldMapView: View {
    @State private var dots: [WorldDotGrid.Dot] = []

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

                ScrollView {
                    VStack(spacing: 14) {
                        constellation(visited: stats.daysPerCountry, home: home)
                            .aspectRatio(2.1, contentMode: .fit)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)

                        summary(stats: stats)

                        ledger(ranked: ranked, home: home, today: today, earliest: earliest)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Your world")
            .navigationDestination(for: String.self) { code in
                CountryDetailView(countryCode: code)
            }
            .navigationDestination(for: TripSegment.self) { segment in
                TripDetailView(segment: segment)
            }
            .task {
                if dots.isEmpty {
                    dots = await Task.detached {
                        guard let shapes = try? WorldMapShapes() else { return [] }
                        return WorldDotGrid.compute(shapes: shapes)
                    }.value
                }
            }
        }
    }

    // MARK: - The constellation

    private func constellation(visited: [String: Int], home: String?) -> some View {
        Canvas { context, size in
            guard !dots.isEmpty else { return }
            let maxDays = visited.values.max() ?? 1
            let radius = min(size.width / 66 * 0.34, size.height / 30 * 0.34)

            // Pass 1: soft glow halos under lit dots.
            for dot in dots {
                let isHome = dot.code == home
                guard isHome || visited[dot.code] != nil else { continue }
                let center = point(for: dot, in: size)
                let halo = isHome ? radius * 3.2 : radius * 2.4
                let color = isHome ? Theme.amber : Theme.aurora1
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - halo, y: center.y - halo,
                        width: halo * 2, height: halo * 2
                    )),
                    with: .color(color.opacity(0.10))
                )
            }

            // Pass 2: the dots themselves.
            for dot in dots {
                let center = point(for: dot, in: size)
                let color: Color
                var dotRadius = radius
                if dot.code == home {
                    color = Theme.amber
                    dotRadius = radius * 1.15
                } else if let days = visited[dot.code] {
                    let ratio = Double(days) / Double(maxDays)
                    color = Theme.aurora1.opacity(0.55 + 0.45 * ratio)
                    dotRadius = radius * 1.05
                } else {
                    color = Theme.ink3.opacity(0.30)
                }
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - dotRadius, y: center.y - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    )),
                    with: .color(color)
                )
            }
        }
    }

    private func point(for dot: WorldDotGrid.Dot, in size: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(dot.unitX) * size.width, y: CGFloat(dot.unitY) * size.height)
    }

    private func summary(stats: TravelStats) -> some View {
        let percent = Int((Double(stats.countriesVisited) / 195.0 * 100).rounded())
        return VStack(spacing: 2) {
            Text("\(stats.countriesVisited) countries · \(percent)% of the world")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("\(stats.travelDays) travel days · \(stats.borderCrossings) crossings")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink3)
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
