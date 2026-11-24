import SwiftUI
import WorldTrackerKit

/// The collection: every country as a stamp, continents as rings, badges to
/// chase, the long-view numbers, and a wishlist that ticks itself off.
struct PassportView: View {
    enum StampOrder: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case mostDays = "Most days"
        case name = "A to Z"
        var id: String { rawValue }
    }

    @State private var order: StampOrder = .newest
    @State private var showWishPicker = false
    @State private var showAllBadges = false

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var insightsStore: InsightsStore { AppContainer.shared.insightsStore }
    private var router: AppRouter { AppContainer.shared.router }

    /// Three across on a phone; more as the canvas widens.
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        let _ = store.changeToken
        let summary = insightsStore.summary(using: store)

        NavigationStack {
            ZStack {
                AuroraBackground(intensity: 0.8)

                ScrollView {
                    Group {
                        if isWide && !summary.stamps.isEmpty {
                            HStack(alignment: .top, spacing: 28) {
                                VStack(alignment: .leading, spacing: 14) {
                                    cover(summary).padding(.top, 8)
                                    continents(summary)
                                    badges(summary)
                                    wishlist(summary)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(alignment: .leading, spacing: 14) {
                                    stamps(summary).padding(.top, 8)
                                    longView(summary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                cover(summary)
                                    .padding(.top, 8)

                                if summary.stamps.isEmpty {
                                    EmptyStateCTAs(
                                        icon: "book.closed.fill",
                                        title: "No stamps yet",
                                        message: "Every country you're logged in gets a stamp here. Rebuild your past from photos to fill the pages now."
                                    )
                                    .padding(.top, 12)
                                } else {
                                    continents(summary)
                                    stamps(summary)
                                    badges(summary)
                                    longView(summary)
                                }

                                wishlist(summary)
                            }
                        }
                    }
                    .padding(.horizontal, isWide ? 28 : 18)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle(Theme.title("Passport"))
            .navigationDestination(for: String.self) { code in
                CountryDetailView(countryCode: code)
            }
            .navigationDestination(for: TripSegment.self) { segment in
                TripDetailView(segment: segment)
            }
            .sheet(isPresented: $showWishPicker) {
                CountryPickerView { code in
                    if !insightsStore.isWished(code) {
                        insightsStore.toggleWish(code)
                    }
                }
            }
            .task { await insightsStore.warm(store: store) }
            .onChange(of: store.changeToken) {
                Task { await insightsStore.warm(store: store) }
            }
        }
    }

    // MARK: - Cover

    private func cover(_ summary: InsightsStore.Summary) -> some View {
        let count = summary.stamps.count
        let share = Double(count) / Double(MilestoneEngine.worldCountryCount)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COUNTRIES")
                        .font(Theme.label(11, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(Theme.aurora1)
                    Text("\(count)")
                        .font(Theme.isBold ? Theme.poster(96) : Theme.display(56, weight: .heavy))
                        .foregroundStyle(Theme.auroraGradient)
                        .contentTransition(.numericText())
                }
                Spacer()
                if !Theme.isBold {
                    MiniGlobe(size: 58, showsPlane: false)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressBar(fraction: share, height: 6)
                Text("\(Int((share * 100).rounded()))% of the world's \(MilestoneEngine.worldCountryCount) countries")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink2)
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(alignment: .top) {
                MetricColumn(value: "\(summary.continentsVisited)", label: "Continents")
                Spacer()
                MetricColumn(value: summary.insights.travelDays.grouped, label: "Travel days")
                Spacer()
                MetricColumn(value: summary.insights.totalKm.grouped, label: "Km between")
                Spacer()
                MetricColumn(
                    value: "\(summary.unlockedCount)", label: "Badges",
                    tint: AnyShapeStyle(Theme.amber)
                )
            }
        }
        .padding(18)
        .nightCard()
    }

    // MARK: - Continents

    private func continents(_ summary: InsightsStore.Summary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Continents")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 14
            ) {
                ForEach(summary.continents) { ContinentRing(progress: $0) }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .nightCard()
        }
    }

    // MARK: - Stamps

    private func ordered(_ stamps: [PassportStamp]) -> [PassportStamp] {
        switch order {
        case .newest: return stamps
        case .mostDays: return stamps.sorted { ($0.totalDays, $1.code) > ($1.totalDays, $0.code) }
        case .name: return stamps.sorted { countryName($0.code) < countryName($1.code) }
        }
    }

    private func stamps(_ summary: InsightsStore.Summary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title: "Stamps")
                Menu {
                    Picker("Order", selection: $order) {
                        ForEach(StampOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(order.rawValue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.aurora1)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ordered(summary.stamps)) { stamp in
                    NavigationLink(value: stamp.code) {
                        StampView(stamp: stamp, isHome: stamp.code == store.homeCountry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .nightCard()
        }
    }

    // MARK: - Badges

    private func badges(_ summary: InsightsStore.Summary) -> some View {
        // Earned first, then the closest to earning.
        let sorted = summary.achievements.sorted {
            ($0.isUnlocked ? 1 : 0, $0.fraction) > ($1.isUnlocked ? 1 : 0, $1.fraction)
        }
        let shown = showAllBadges ? sorted : Array(sorted.prefix(6))
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(
                title: "Badges · \(summary.unlockedCount) of \(summary.achievements.count)",
                actionTitle: showAllBadges ? "Fewer" : "All",
                action: { withAnimation(.snappy) { showAllBadges.toggle() } }
            )
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(shown) { BadgeCell(achievement: $0) }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .nightCard()
        }
    }

    // MARK: - The long view

    private func longView(_ summary: InsightsStore.Summary) -> some View {
        let insights = summary.insights
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "The long view")

            VStack(alignment: .leading, spacing: 12) {
                Text("Countries per year")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                YearBars(years: insights.byYear)
                Text("Solid = countries new that year")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nightCard()

            VStack(spacing: 0) {
                if insights.totalKm > 0 {
                    factRow(
                        "airplane", "Distance between countries",
                        "\(insights.totalKm.grouped) km",
                        note: "Measured between where you stayed in each country, across \(insights.legs) border crossings"
                    )
                }
                if let farthest = insights.farthest {
                    factRow(
                        "location.north.line.fill", "Farthest from home",
                        "\(flagEmoji(farthest.code)) \(farthest.km.grouped) km"
                    )
                }
                if let trip = insights.longestAway {
                    factRow(
                        "suitcase.fill", "Longest trip",
                        "\(trip.dayCount) days",
                        note: trip.countryCodes.map(flagEmoji).joined(separator: " ")
                            + "  " + DayFormat.monthYear(trip.startDay)
                    )
                }
                if let average = insights.averageTripDays {
                    factRow("ruler", "Typical trip", String(format: "%.1f days", average))
                }
                if let month = insights.favouriteMonth {
                    factRow(
                        "calendar", "Month you travel most",
                        DateFormatter().monthSymbols[month - 1]
                    )
                }
                factRow(
                    "house.fill", "Longest stretch at home",
                    "\(insights.longestHomeStretch) days"
                )
                factRow(
                    "chart.pie.fill", "Share of days away",
                    "\(Int((insights.awayShare * 100).rounded()))%",
                    note: "\(insights.travelDays.grouped) of \(insights.trackedDays.grouped) tracked days",
                    isLast: summary.extremes.northernmost == nil
                )
                if let north = summary.extremes.northernmost,
                   let south = summary.extremes.southernmost {
                    factRow("arrow.up", "Northernmost", cityLine(north))
                    factRow("arrow.down", "Southernmost", cityLine(south), isLast: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .nightCard()
        }
    }

    private func cityLine(_ city: CityDays) -> String {
        let flag = city.countryCode.map(flagEmoji) ?? ""
        return "\(flag) \(city.name)".trimmingCharacters(in: .whitespaces)
    }

    private func factRow(
        _ symbol: String, _ label: String, _ value: String,
        note: String? = nil, isLast: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.aurora1)
                    .frame(width: 20)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.ink2)
                    if let note {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink3)
                    }
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            if !isLast {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Wishlist

    private func wishlist(_ summary: InsightsStore.Summary) -> some View {
        let done = summary.wishlist.filter(\.isVisited).count
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(
                title: summary.wishlist.isEmpty
                    ? "Wishlist"
                    : "Wishlist · \(done) of \(summary.wishlist.count)",
                actionTitle: "Add",
                action: { showWishPicker = true }
            )

            if summary.wishlist.isEmpty {
                Button {
                    showWishPicker = true
                } label: {
                    HStack(spacing: 13) {
                        IconTile(symbol: "heart.fill", size: 42, tint: Theme.aurora2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Where next?")
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text("Add the countries you want to see. They tick themselves off the day you arrive.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink3)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(14)
                    .nightCard()
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.wishlist.enumerated()), id: \.element.id) { index, entry in
                        wishRow(entry)
                        if index < summary.wishlist.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .nightCard()
            }
        }
    }

    private func wishRow(_ entry: WishlistEntry) -> some View {
        HStack(spacing: 12) {
            Text(flagEmoji(entry.code)).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(countryName(entry.code))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .strikethrough(entry.isVisited, color: Theme.ink3)
                if let day = entry.visitedOn {
                    Text("Visited \(DayFormat.monthYear(day))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.good)
                } else if let continent = ContinentTable.continent(of: entry.code) {
                    Text(continent.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                }
            }
            Spacer()
            if entry.isVisited {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.good)
            }
            Button {
                withAnimation(.snappy) { insightsStore.toggleWish(entry.code) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(countryName(entry.code)) from wishlist")
        }
        .padding(.vertical, 9)
    }
}

#Preview {
    PassportView()
        .preferredColorScheme(.dark)
}
