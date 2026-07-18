import SwiftUI
import WorldTrackerKit

/// The nine Wrapped pages. W2 lands them static-first: real layout, real data,
/// a simple appear fade. W3 layers on the full choreography (roll-ups,
/// stamp-slams, particles, haptics) behind the same `progress` value.
///
/// Every page takes `externalProgress` so a future video exporter can drive
/// the exact frames; nil means "animate yourself on appear".

// MARK: - Shared bits

private struct WrappedKicker: View {
    let text: String
    var color: Color = Theme.aurora1

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(3)
            .foregroundStyle(color)
    }
}

private struct WrappedBigNumber: View {
    let value: Int
    var size: CGFloat = 96

    var body: some View {
        Text("\(value)")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.auroraGradient)
            .contentTransition(.numericText())
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

/// Appear-driven progress with the external override every page honors.
private struct PageReveal: ViewModifier {
    let externalProgress: Double?
    @State private var appeared = false

    private var p: Double { externalProgress ?? (appeared ? 1 : 0) }

    func body(content: Content) -> some View {
        content
            .opacity(0.25 + 0.75 * p)
            .offset(y: (1 - p) * 18)
            .onAppear {
                withAnimation(.spring(duration: 0.7)) { appeared = true }
            }
    }
}

private extension View {
    func pageReveal(_ externalProgress: Double?) -> some View {
        modifier(PageReveal(externalProgress: externalProgress))
    }
}

private let monthNames = DateFormatter().monthSymbols ?? []

// MARK: - 1 · Opener

struct WrappedOpenerPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            MiniGlobe(size: 118)
            WrappedKicker(text: "YOUR YEAR IN TRAVEL")
            Text(String(data.stats.year))
                .font(.system(size: 92, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.auroraGradient)
            Text(data.isPartialYear
                 ? "So far — the year is still writing itself."
                 : "\(data.stats.trackedDays) days, remembered for you.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink2)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .pageReveal(externalProgress)
    }
}

// MARK: - 2 · Countries count

struct WrappedCountriesPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            WrappedKicker(text: "YOU SET FOOT IN")
            WrappedBigNumber(value: data.stats.countriesVisited, size: 120)
            Text(data.stats.countriesVisited == 1 ? "country" : "countries")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 44), spacing: 10)],
                spacing: 10
            ) {
                ForEach(data.stats.firstAppearanceOrder.prefix(24), id: \.self) { code in
                    FlagChip(code: code, size: 42)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)

            if data.stats.borderCrossings > 0 {
                Text("\(data.stats.borderCrossings) border \(data.stats.borderCrossings == 1 ? "crossing" : "crossings")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 6)
            }
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }
}

// MARK: - 3 · Travel days (dot grid)

struct WrappedTravelDaysPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            WrappedKicker(text: "DAYS AWAY FROM HOME")
            WrappedBigNumber(value: data.stats.travelDays, size: 110)

            dotGrid
                .frame(height: 150)
                .padding(.horizontal, 34)
                .padding(.top, 4)

            if let busiest = data.stats.busiestMonth,
               busiest.month >= 1, busiest.month <= monthNames.count {
                Text("BUSIEST · \(monthNames[busiest.month - 1].uppercased()) · \(busiest.travelDays) DAYS")
                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(Theme.amber)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Theme.amber.opacity(0.55), lineWidth: 1.2)
                    )
                    .rotationEffect(.degrees(-2))
                    .padding(.top, 10)
            }
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }

    /// The whole year as dots — travel days lit, in true calendar positions.
    private var dotGrid: some View {
        Canvas { context, size in
            let flags = data.travelDayFlags
            guard !flags.isEmpty else { return }
            let columns = 26
            let rows = Int((Double(flags.count) / Double(columns)).rounded(.up))
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let dot = cell * 0.55
            let xInset = (size.width - cell * CGFloat(columns)) / 2

            for (i, isTravel) in flags.enumerated() {
                let col = i % columns
                let row = i / columns
                let rect = CGRect(
                    x: xInset + CGFloat(col) * cell + (cell - dot) / 2,
                    y: CGFloat(row) * cell + (cell - dot) / 2,
                    width: dot,
                    height: dot
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(isTravel ? Theme.aurora1 : Theme.hairline2)
                )
            }
        }
    }
}

// MARK: - 4 · Top-country podium

struct WrappedPodiumPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        let top = Array(data.stats.topCountries.prefix(3))
        // Podium order: 2nd, 1st, 3rd.
        let arranged: [(rank: Int, entry: YearInReviewStats.RankedCountry)] = {
            switch top.count {
            case 0: return []
            case 1: return [(1, top[0])]
            case 2: return [(2, top[1]), (1, top[0])]
            default: return [(2, top[1]), (1, top[0]), (3, top[2])]
            }
        }()
        let maxDays = top.first?.days ?? 1

        return VStack(spacing: 20) {
            Spacer()
            WrappedKicker(text: "WHERE YOUR YEAR LIVED")

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(arranged, id: \.entry.code) { rank, entry in
                    VStack(spacing: 8) {
                        if rank == 1 {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.amber)
                        }
                        FlagChip(code: entry.code, size: rank == 1 ? 52 : 40)
                        Text("\(entry.days)d")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(rank == 1 ? Theme.amber : Theme.aurora1)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                rank == 1
                                    ? AnyShapeStyle(Theme.auroraGradient)
                                    : AnyShapeStyle(Theme.cardRaised)
                            )
                            .frame(
                                width: 74,
                                height: max(34, 150 * CGFloat(entry.days) / CGFloat(maxDays))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Theme.hairline2, lineWidth: 1)
                            )
                        Text(countryName(entry.code))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .lineLimit(1)
                            .frame(width: 84)
                    }
                }
            }
            .padding(.top, 6)

            if let home = data.stats.homeCountry,
               data.stats.topCountries.first?.code == home {
                Text("Home held the crown — the away days are below.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }
}

// MARK: - 5 · Longest trip

struct WrappedLongestTripPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            WrappedKicker(text: "YOUR LONGEST TRIP")

            if let trip = data.stats.longestTrip {
                arc
                    .frame(height: 110)
                    .padding(.horizontal, 40)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    WrappedBigNumber(value: trip.dayCount, size: 84)
                    Text(trip.dayCount == 1 ? "day away" : "days away")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }

                Text(DayFormat.shortRange(trip.startDay, trip.endDay, todayYear: data.stats.year))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink2)

                HStack(spacing: 8) {
                    ForEach(trip.countryCodes.prefix(6), id: \.self) { code in
                        HStack(spacing: 5) {
                            Text(flagEmoji(code)).font(.system(size: 15))
                            Text(countryName(code))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .nightCard()
                    }
                }
                .padding(.top, 6)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .pageReveal(externalProgress)
    }

    /// Decorative flight arc with a comet head — W3 draws it progressively.
    private var arc: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h * 0.9))
            path.addQuadCurve(
                to: CGPoint(x: w, y: h * 0.9),
                control: CGPoint(x: w / 2, y: -h * 0.4)
            )
            return ZStack {
                path.stroke(
                    Theme.auroraGradient,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7])
                )
                Circle()
                    .fill(Theme.aurora1)
                    .frame(width: 8, height: 8)
                    .position(x: w, y: h * 0.9)
                    .shadow(color: Theme.aurora1.opacity(0.8), radius: 8)
                Text("✈️")
                    .font(.system(size: 20))
                    .position(x: w / 2, y: h * 0.12)
            }
        }
    }
}

// MARK: - 6 · First visits (new stamps)

struct WrappedFirstVisitsPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        let firsts = data.stats.firstVisits

        return VStack(spacing: 16) {
            Spacer()
            WrappedKicker(text: "NEW STAMPS", color: Theme.amber)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                WrappedBigNumber(value: firsts.count, size: 84)
                Text(firsts.count == 1 ? "country you'd\nnever seen before" : "countries you'd\nnever seen before")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(firsts.prefix(8).enumerated()), id: \.element) { index, code in
                    VStack(spacing: 6) {
                        Text(flagEmoji(code)).font(.system(size: 30))
                        Text(countryName(code).uppercased())
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(Theme.amber)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.amber.opacity(0.5), lineWidth: 1.4)
                    )
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)

            if firsts.count > 8 {
                Text("+ \(firsts.count - 8) more")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }
}

// MARK: - 7 · The year's map

struct WrappedMapPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            WrappedKicker(text: "YOUR WORLD, \(String(data.stats.year))")

            WrappedMapCanvas(
                shapes: data.shapes,
                daysPerCountry: data.daysPerCountry,
                homeCountry: data.stats.homeCountry,
                homeCentroid: data.homeCentroid,
                arcTargets: data.arcTargets,
                lightOrder: data.stats.firstAppearanceOrder,
                litProgress: externalProgress ?? 1,
                arcProgress: externalProgress ?? 1
            )
            .aspectRatio(2.2, contentMode: .fit)
            .padding(.horizontal, 12)

            HStack(spacing: 22) {
                mapStat(value: data.stats.countriesVisited, label: "COUNTRIES")
                mapStat(value: data.stats.travelDays, label: "TRAVEL DAYS")
                mapStat(value: data.stats.firstVisits.count, label: "NEW")
            }
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }

    private func mapStat(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.auroraGradient)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.ink3)
        }
    }
}

// MARK: - 8 · Photo moments

struct WrappedPhotosPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        let moments = data.photoMoments.filter { data.thumbnails[$0.assetID] != nil }

        return VStack(spacing: 18) {
            Spacer()
            WrappedKicker(text: "MOMENTS YOU KEPT")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(moments.prefix(9)) { moment in
                    if let image = data.thumbnails[moment.assetID] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(minWidth: 0)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                if let country = moment.countryCode {
                                    Text(flagEmoji(country))
                                        .font(.system(size: 14))
                                        .padding(5)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 26)

            if let best = moments.first, let city = best.city {
                Text("\(city) alone gave you \(best.photoCount) photos in a day")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink2)
            }
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }
}

// MARK: - 9 · Closer

struct WrappedCloserPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MiniGlobe(size: 64, showsPlane: false)
            Text("That was \(String(data.stats.year)).")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 0) {
                closerRow(label: "Countries", value: "\(data.stats.countriesVisited)")
                divider
                closerRow(label: "Travel days", value: "\(data.stats.travelDays)")
                divider
                closerRow(label: "Border crossings", value: "\(data.stats.borderCrossings)")
                if !data.stats.firstVisits.isEmpty {
                    divider
                    closerRow(label: "New countries", value: "\(data.stats.firstVisits.count)")
                }
                if let trip = data.stats.longestTrip {
                    divider
                    closerRow(label: "Longest trip", value: "\(trip.dayCount) days")
                }
            }
            .padding(.vertical, 6)
            .nightCard()
            .padding(.horizontal, 40)

            Text("BEEN THERE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(3.2)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 8)

            Text(data.isPartialYear
                 ? "Still counting — come back in January."
                 : "Sharing arrives with the next update.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink3)
            Spacer()
            Spacer()
        }
        .pageReveal(externalProgress)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.horizontal, 14)
    }

    private func closerRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.aurora1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
