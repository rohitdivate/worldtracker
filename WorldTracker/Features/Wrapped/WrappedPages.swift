import SwiftUI
import WorldTrackerKit

/// The nine Wrapped pages, fully choreographed. Every page is a pure function
/// of a 0…1 progress value: internally a TimelineView clock drives it (and
/// pauses when the choreography completes); externally a video exporter can
/// hand in exact frames via `externalProgress`.

// MARK: - Choreography plumbing

/// Time-driven page progress. Ticks at display rate until the choreography
/// finishes, then freezes so a resting page costs nothing.
private struct WrappedPageClock<Content: View>: View {
    var externalProgress: Double?
    var duration: Double
    @ViewBuilder var content: (Double) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        if let externalProgress {
            content(externalProgress)
        } else if reduceMotion {
            content(1)
        } else {
            TimelineView(.animation(paused: finished)) { timeline in
                let p = min(1, timeline.date.timeIntervalSince(start) / duration)
                content(p)
                    .onChange(of: p >= 1) { _, done in
                        if done { finished = true }
                    }
            }
        }
    }
}

/// Maps overall page progress onto a sub-animation's 0…1 window.
private func stage(_ p: Double, _ from: Double, _ to: Double) -> Double {
    guard to > from else { return p >= to ? 1 : 0 }
    return min(1, max(0, (p - from) / (to - from)))
}

private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

/// Overshoot-and-settle — the stamp-slam curve.
private func easeOutBack(_ x: Double) -> Double {
    let c1 = 1.70158
    let c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}

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

/// Rolling counter: recomputed per frame, so it counts up honestly.
private struct RollingNumber: View {
    let value: Int
    let reveal: Double
    var size: CGFloat = 96

    var body: some View {
        Text("\(Int((Double(value) * easeOutCubic(reveal)).rounded()))")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.auroraGradient)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .monospacedDigit()
    }
}

/// Fires a haptic exactly once per threshold crossing of a counter.
private struct HapticOnStep: ViewModifier {
    let step: Int
    let sound: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: step) { old, new in
            if new > old { sound() }
        }
    }
}

private let monthNames = DateFormatter().monthSymbols ?? []

// MARK: - 1 · Opener

struct WrappedOpenerPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.0) { p in
            ZStack {
                ParticleField(opacity: stage(p, 0.3, 1))

                VStack(spacing: 22) {
                    Spacer()
                    MiniGlobe(size: 118)
                        .scaleEffect(0.4 + 0.6 * easeOutBack(stage(p, 0, 0.4)))
                        .opacity(stage(p, 0, 0.25))
                    WrappedKicker(text: "YOUR YEAR IN TRAVEL")
                        .opacity(stage(p, 0.25, 0.45))
                    Text(String(data.stats.year))
                        .font(.system(size: 92, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.auroraGradient)
                        .opacity(stage(p, 0.35, 0.6))
                        .offset(y: (1 - easeOutBack(stage(p, 0.35, 0.7))) * 46)
                    Text(data.isPartialYear
                         ? "So far — the year is still writing itself."
                         : "\(data.stats.trackedDays) days, remembered for you.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink2)
                        .opacity(stage(p, 0.65, 0.9))
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

// MARK: - 2 · Countries count

struct WrappedCountriesPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.4) { p in
            let flags = Array(data.stats.firstAppearanceOrder.prefix(24))
            let flagsShown = Int(easeOutCubic(stage(p, 0.4, 0.95)) * Double(flags.count))

            VStack(spacing: 18) {
                Spacer()
                WrappedKicker(text: "YOU SET FOOT IN")
                    .opacity(stage(p, 0, 0.2))
                RollingNumber(value: data.stats.countriesVisited,
                              reveal: stage(p, 0.1, 0.55), size: 120)
                    .modifier(HapticOnStep(step: p >= 0.55 ? 1 : 0) {
                        HapticsDirector.shared.stampSlam()
                    })
                Text(data.stats.countriesVisited == 1 ? "country" : "countries")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .opacity(stage(p, 0.3, 0.5))

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 44), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Array(flags.enumerated()), id: \.element) { index, code in
                        let shown = index < flagsShown
                        FlagChip(code: code, size: 42)
                            .scaleEffect(shown ? 1 : 0.3)
                            .opacity(shown ? 1 : 0)
                            .animation(.spring(duration: 0.35), value: shown)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)

                if data.stats.borderCrossings > 0 {
                    Text("\(data.stats.borderCrossings) border \(data.stats.borderCrossings == 1 ? "crossing" : "crossings")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .padding(.top, 6)
                        .opacity(stage(p, 0.85, 1))
                }
                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - 3 · Travel days (dot-grid ignition)

struct WrappedTravelDaysPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.8) { p in
            let stampIn = stage(p, 0.82, 0.95)

            VStack(spacing: 18) {
                Spacer()
                WrappedKicker(text: "DAYS AWAY FROM HOME")
                    .opacity(stage(p, 0, 0.2))
                RollingNumber(value: data.stats.travelDays,
                              reveal: stage(p, 0.1, 0.6), size: 110)

                dotGrid(ignition: easeOutCubic(stage(p, 0.2, 0.8)))
                    .frame(height: 150)
                    .padding(.horizontal, 34)
                    .padding(.top, 4)
                    .opacity(stage(p, 0.1, 0.3))

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
                        .rotationEffect(.degrees(-8 + 6 * easeOutBack(stampIn)))
                        .scaleEffect(0.4 + 0.6 * easeOutBack(stampIn))
                        .opacity(stampIn)
                        .padding(.top, 10)
                        .modifier(HapticOnStep(step: stampIn >= 1 ? 1 : 0) {
                            HapticsDirector.shared.stampSlam()
                        })
                }
                Spacer()
                Spacer()
            }
        }
    }

    /// The whole year as dots in true calendar positions; travel days ignite
    /// chronologically as `ignition` sweeps 0→1.
    private func dotGrid(ignition: Double) -> some View {
        Canvas { context, size in
            let flags = data.travelDayFlags
            guard !flags.isEmpty else { return }
            let travelTotal = max(1, flags.lazy.filter { $0 }.count)
            let litTravel = Int((Double(travelTotal) * ignition).rounded())

            let columns = 26
            let rows = Int((Double(flags.count) / Double(columns)).rounded(.up))
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let dot = cell * 0.55
            let xInset = (size.width - cell * CGFloat(columns)) / 2

            var travelSeen = 0
            for (i, isTravel) in flags.enumerated() {
                var lit = false
                if isTravel {
                    travelSeen += 1
                    lit = travelSeen <= litTravel
                }
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
                    with: .color(lit ? Theme.aurora1 : Theme.hairline2)
                )
                if lit, travelSeen == litTravel, ignition < 1 {
                    // The freshly-lit dot glows.
                    context.fill(
                        Path(ellipseIn: rect.insetBy(dx: -dot * 0.5, dy: -dot * 0.5)),
                        with: .color(Theme.aurora1.opacity(0.35))
                    )
                }
            }
        }
    }
}

// MARK: - 4 · Top-country podium

struct WrappedPodiumPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.4) { p in
            let top = Array(data.stats.topCountries.prefix(3))
            let arranged: [(rank: Int, entry: YearInReviewStats.RankedCountry)] = {
                switch top.count {
                case 0: return []
                case 1: return [(1, top[0])]
                case 2: return [(2, top[1]), (1, top[0])]
                default: return [(2, top[1]), (1, top[0]), (3, top[2])]
                }
            }()
            let maxDays = top.first?.days ?? 1
            let crownIn = stage(p, 0.75, 0.95)

            VStack(spacing: 20) {
                Spacer()
                WrappedKicker(text: "WHERE YOUR YEAR LIVED")
                    .opacity(stage(p, 0, 0.2))

                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(arranged, id: \.entry.code) { rank, entry in
                        // Bars rise in podium-ceremony order: 3rd, 2nd, then 1st.
                        let riseStart = rank == 1 ? 0.45 : (rank == 2 ? 0.3 : 0.15)
                        let rise = easeOutBack(stage(p, riseStart, riseStart + 0.3))

                        VStack(spacing: 8) {
                            if rank == 1 {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.amber)
                                    .offset(y: (1 - easeOutBack(crownIn)) * -26)
                                    .opacity(crownIn)
                                    .modifier(HapticOnStep(step: crownIn >= 1 ? 1 : 0) {
                                        HapticsDirector.shared.celebrate()
                                    })
                            }
                            FlagChip(code: entry.code, size: rank == 1 ? 52 : 40)
                                .opacity(stage(p, riseStart, riseStart + 0.2))
                            Text("\(entry.days)d")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(rank == 1 ? Theme.amber : Theme.aurora1)
                                .opacity(stage(p, riseStart + 0.1, riseStart + 0.3))
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    rank == 1
                                        ? AnyShapeStyle(Theme.auroraGradient)
                                        : AnyShapeStyle(Theme.cardRaised)
                                )
                                .frame(
                                    width: 74,
                                    height: max(6, max(34, 150 * CGFloat(entry.days) / CGFloat(maxDays)) * rise)
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
                                .opacity(stage(p, riseStart, riseStart + 0.25))
                        }
                    }
                }
                .padding(.top, 6)

                if let home = data.stats.homeCountry,
                   data.stats.topCountries.first?.code == home {
                    Text("Home held the crown — the away days are below.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink3)
                        .opacity(stage(p, 0.85, 1))
                }
                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - 5 · Longest trip

struct WrappedLongestTripPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.6) { p in
            VStack(spacing: 16) {
                Spacer()
                WrappedKicker(text: "YOUR LONGEST TRIP")
                    .opacity(stage(p, 0, 0.2))

                if let trip = data.stats.longestTrip {
                    arc(draw: easeOutCubic(stage(p, 0.1, 0.6)))
                        .frame(height: 110)
                        .padding(.horizontal, 40)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        RollingNumber(value: trip.dayCount,
                                      reveal: stage(p, 0.35, 0.75), size: 84)
                        Text(trip.dayCount == 1 ? "day away" : "days away")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .opacity(stage(p, 0.5, 0.7))
                    }

                    Text(DayFormat.shortRange(trip.startDay, trip.endDay, todayYear: data.stats.year))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink2)
                        .opacity(stage(p, 0.6, 0.8))

                    HStack(spacing: 8) {
                        ForEach(Array(trip.countryCodes.prefix(6).enumerated()), id: \.element) { index, code in
                            let chipIn = stage(p, 0.65 + Double(index) * 0.07, 0.8 + Double(index) * 0.07)
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
                            .scaleEffect(0.6 + 0.4 * easeOutBack(chipIn))
                            .opacity(chipIn)
                        }
                    }
                    .padding(.top, 6)
                }
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    /// The flight arc draws itself; the comet rides its tip.
    private func arc(draw: Double) -> some View {
        GeometryReader { geo in
            arcContent(size: geo.size, draw: CGFloat(draw))
        }
    }

    private func arcContent(size: CGSize, draw: CGFloat) -> some View {
        let from = CGPoint(x: 0, y: size.height * 0.9)
        let to = CGPoint(x: size.width, y: size.height * 0.9)
        let control = CGPoint(x: size.width / 2, y: -size.height * 0.4)
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        let tip = quadBezierPoint(from: from, control: control, to: to, t: draw)

        return ZStack {
            path.trimmedPath(from: 0, to: max(0.001, draw))
                .stroke(
                    Theme.auroraGradient,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7])
                )
            Circle()
                .fill(Theme.aurora1)
                .frame(width: 8, height: 8)
                .position(tip)
                .shadow(color: Theme.aurora1.opacity(0.8), radius: 8)
                .opacity(draw > 0 ? 1 : 0)
            Text("✈️")
                .font(.system(size: 20))
                .position(x: tip.x, y: tip.y - 16)
                .opacity(draw > 0.05 ? 1 : 0)
        }
    }

    /// Quadratic Bézier point at t — the comet's seat.
    private func quadBezierPoint(from: CGPoint, control: CGPoint, to: CGPoint, t: CGFloat) -> CGPoint {
        let mt: CGFloat = 1 - t
        let x: CGFloat = mt * mt * from.x + 2 * mt * t * control.x + t * t * to.x
        let y: CGFloat = mt * mt * from.y + 2 * mt * t * control.y + t * t * to.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 6 · First visits (stamp-slam)

struct WrappedFirstVisitsPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 3.0) { p in
            let firsts = data.stats.firstVisits
            let shownStamps = Array(firsts.prefix(8))
            let slammed = shownStamps.indices.filter { index in
                stage(p, slamStart(index), slamStart(index) + 0.1) >= 1
            }.count

            ZStack {
                AuroraBurstView(progress: stage(p, 0.28, 0.75))
                    .frame(width: 320, height: 320)

                VStack(spacing: 16) {
                    Spacer()
                    WrappedKicker(text: "NEW STAMPS", color: Theme.amber)
                        .opacity(stage(p, 0, 0.15))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        RollingNumber(value: firsts.count,
                                      reveal: stage(p, 0.05, 0.3), size: 84)
                        Text(firsts.count == 1 ? "country you'd\nnever seen before" : "countries you'd\nnever seen before")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .opacity(stage(p, 0.15, 0.3))
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(Array(shownStamps.enumerated()), id: \.element) { index, code in
                            let slam = easeOutBack(stage(p, slamStart(index), slamStart(index) + 0.12))
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
                            .rotationEffect(.degrees(Double(index.isMultiple(of: 2) ? -2 : 2)))
                            .scaleEffect(2.2 - 1.2 * slam)
                            .opacity(slam)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    .modifier(HapticOnStep(step: slammed) {
                        HapticsDirector.shared.stampSlam()
                    })

                    if firsts.count > 8 {
                        Text("+ \(firsts.count - 8) more")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                            .opacity(stage(p, 0.9, 1))
                    }
                    Spacer()
                    Spacer()
                }
            }
        }
    }

    private func slamStart(_ index: Int) -> Double {
        0.3 + Double(index) * 0.09
    }
}

// MARK: - 7 · The year's map

struct WrappedMapPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 3.6) { p in
            VStack(spacing: 20) {
                Spacer()
                WrappedKicker(text: "YOUR WORLD, \(String(data.stats.year))")
                    .opacity(stage(p, 0, 0.15))

                WrappedMapCanvas(
                    shapes: data.shapes,
                    daysPerCountry: data.daysPerCountry,
                    homeCountry: data.stats.homeCountry,
                    homeCentroid: data.homeCentroid,
                    arcTargets: data.arcTargets,
                    lightOrder: data.stats.firstAppearanceOrder,
                    litProgress: easeOutCubic(stage(p, 0.05, 0.6)),
                    arcProgress: easeOutCubic(stage(p, 0.35, 0.95))
                )
                .aspectRatio(2.2, contentMode: .fit)
                .padding(.horizontal, 12)
                .opacity(stage(p, 0, 0.2))

                HStack(spacing: 22) {
                    mapStat(value: data.stats.countriesVisited, label: "COUNTRIES",
                            reveal: stage(p, 0.55, 0.8))
                    mapStat(value: data.stats.travelDays, label: "TRAVEL DAYS",
                            reveal: stage(p, 0.65, 0.9))
                    mapStat(value: data.stats.firstVisits.count, label: "NEW",
                            reveal: stage(p, 0.75, 1))
                }
                Spacer()
                Spacer()
            }
        }
    }

    private func mapStat(value: Int, label: String, reveal: Double) -> some View {
        VStack(spacing: 3) {
            Text("\(Int((Double(value) * easeOutCubic(reveal)).rounded()))")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.auroraGradient)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.ink3)
        }
        .opacity(reveal)
    }
}

// MARK: - 8 · Photo moments

struct WrappedPhotosPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.6) { p in
            let moments = data.photoMoments.filter { data.thumbnails[$0.assetID] != nil }

            VStack(spacing: 18) {
                Spacer()
                WrappedKicker(text: "MOMENTS YOU KEPT")
                    .opacity(stage(p, 0, 0.2))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(Array(moments.prefix(9).enumerated()), id: \.element.id) { index, moment in
                        if let image = data.thumbnails[moment.assetID] {
                            let flip = easeOutCubic(stage(p, 0.15 + Double(index) * 0.07,
                                                          0.4 + Double(index) * 0.07))
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
                                .rotation3DEffect(
                                    .degrees((1 - flip) * 82),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.6
                                )
                                .opacity(flip)
                        }
                    }
                }
                .padding(.horizontal, 26)

                if let best = moments.first, let city = best.city {
                    Text("\(city) alone gave you \(best.photoCount) photos in a day")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.ink2)
                        .opacity(stage(p, 0.8, 1))
                }
                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - 9 · Closer

struct WrappedCloserPage: View {
    let data: YearInReviewBuilder.WrappedData
    var externalProgress: Double? = nil
    /// W4 wires the rendered share cards through here.
    var shareURLs: [URL] = []

    var body: some View {
        WrappedPageClock(externalProgress: externalProgress, duration: 2.4) { p in
            ZStack {
                ParticleField(opacity: 0.7 * stage(p, 0.3, 1))

                VStack(spacing: 18) {
                    Spacer()
                    MiniGlobe(size: 64, showsPlane: false)
                        .scaleEffect(0.5 + 0.5 * easeOutBack(stage(p, 0, 0.3)))
                        .opacity(stage(p, 0, 0.2))
                    Text("That was \(String(data.stats.year)).")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .opacity(stage(p, 0.15, 0.35))
                        .modifier(HapticOnStep(step: p >= 0.35 ? 1 : 0) {
                            HapticsDirector.shared.celebrate()
                        })

                    VStack(spacing: 0) {
                        let rows = closerRows
                        ForEach(Array(rows.enumerated()), id: \.element.label) { index, row in
                            let rowIn = stage(p, 0.3 + Double(index) * 0.08,
                                              0.45 + Double(index) * 0.08)
                            if index > 0 {
                                Rectangle().fill(Theme.hairline).frame(height: 1)
                                    .padding(.horizontal, 14)
                                    .opacity(rowIn)
                            }
                            closerRow(label: row.label, value: row.value)
                                .offset(x: (1 - easeOutCubic(rowIn)) * 40)
                                .opacity(rowIn)
                        }
                    }
                    .padding(.vertical, 6)
                    .nightCard()
                    .shineEffect(progress: stage(p, 0.72, 0.98))
                    .padding(.horizontal, 40)

                    Text("BEEN THERE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(3.2)
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 8)
                        .opacity(stage(p, 0.8, 1))

                    if !shareURLs.isEmpty {
                        ShareLink(items: shareURLs) {
                            Label("Share your year", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.sky)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        .opacity(stage(p, 0.85, 1))
                    } else {
                        Text(data.isPartialYear
                             ? "Still counting — come back in January."
                             : "Your story, one year at a time.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink3)
                            .opacity(stage(p, 0.85, 1))
                    }
                    Spacer()
                    Spacer()
                }
            }
        }
    }

    private var closerRows: [(label: String, value: String)] {
        var rows: [(String, String)] = [
            ("Countries", "\(data.stats.countriesVisited)"),
            ("Travel days", "\(data.stats.travelDays)"),
            ("Border crossings", "\(data.stats.borderCrossings)"),
        ]
        if !data.stats.firstVisits.isEmpty {
            rows.append(("New countries", "\(data.stats.firstVisits.count)"))
        }
        if let trip = data.stats.longestTrip {
            rows.append(("Longest trip", "\(trip.dayCount) days"))
        }
        return rows
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
