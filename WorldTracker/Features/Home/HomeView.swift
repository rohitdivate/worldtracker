import CoreLocation
import SwiftUI
import WorldTrackerKit

/// Home: the living aurora header + the year at a glance.
struct HomeView: View {
    @Environment(LocationService.self) private var location
    @State private var period: StatsPeriod = .thisYear
    @State private var wrappedYears: [Int] = []
    @State private var buildingYear: Int?
    @State private var presentedWrapped: WrappedPresentation?
    @State private var showAlwaysSheet = false
    @Namespace private var wrappedNS
    /// Regular width = an open iPhone Duo (or any wide canvas): two columns.
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }
    @State private var heroGlobe = HeroGlobeModel()

    /// Non-nil while tracking can't work in the background.
    private var trackingLimitation: TrackingStatusPill.TrackingLimitation? {
        guard location.smartTrackingEnabled else { return nil }
        switch location.authorizationStatus {
        case .authorizedWhenInUse: return .whileUsingOnly
        case .denied, .restricted: return .off
        default: return nil
        }
    }

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var checklist: SetupChecklist { AppContainer.shared.setupChecklist }
    private var router: AppRouter { AppContainer.shared.router }

    /// January only: last year's story, until it's been seen.
    private var heroYear: Int? {
        let (year, month, _) = EpochDay(value: store.todayEpoch).civil()
        guard month == 1 else { return nil }
        let lastYear = year - 1
        guard wrappedYears.contains(lastYear),
              !UserDefaults.standard.bool(forKey: "wrappedSeen-\(lastYear)")
        else { return nil }
        return lastYear
    }

    private var limits: DayLimitStore { AppContainer.shared.dayLimitStore }
    private var insightsStore: InsightsStore { AppContainer.shared.insightsStore }

    var body: some View {
        let _ = store.changeToken  // re-render when the ledger changes
        @Bindable var router = router
        let summary = insightsStore.summary(using: store)
        let statuses = limits.statuses(using: store)

        NavigationStack(path: $router.homePath) {
            ZStack {
                AuroraBackground()

                ScrollView {
                    Group {
                        if isWide {
                            // Where you are and what you're counting on the
                            // left; the year and the collection on the right.
                            HStack(alignment: .top, spacing: 28) {
                                VStack(alignment: .leading, spacing: 14) {
                                    leadingColumn(summary: summary, statuses: statuses)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(alignment: .leading, spacing: 14) {
                                    trailingColumn(summary: summary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                leadingColumn(summary: summary, statuses: statuses)
                                trailingColumn(summary: summary)
                            }
                        }
                    }
                    .padding(.horizontal, isWide ? 28 : 18)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle(Theme.title("Overview"))
            .navigationDestination(for: String.self) { code in
                CountryDetailView(countryCode: code)
            }
            .navigationDestination(for: TripSegment.self) { segment in
                TripDetailView(segment: segment)
            }
            .navigationDestination(for: AppRouter.HomeRoute.self) { route in
                switch route {
                case .limits: DayLimitsView()
                case .limit(let id): DayLimitDetailView(ruleID: id)
                case .gaps(let lower, let upper): GapReviewView(range: lower...max(lower, upper))
                }
            }
            .task {
                wrappedYears = AppContainer.shared.wrappedBuilder.availableYears()
                await refreshHero()
                await checklist.refresh()
                await insightsStore.warm(store: store)
            }
            .onChange(of: store.changeToken) {
                wrappedYears = AppContainer.shared.wrappedBuilder.availableYears()
                Task {
                    await refreshHero()
                    await checklist.refresh()
                    await insightsStore.warm(store: store)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openWrapped)) { _ in
                if let year = wrappedYears.first {
                    openWrapped(year: year)
                }
            }
            .fullScreenCover(item: $presentedWrapped) { presentation in
                WrappedView(data: presentation.data)
                    .navigationTransition(.zoom(sourceID: presentation.id, in: wrappedNS))
            }
            .sheet(isPresented: $showAlwaysSheet) {
                AlwaysUpgradeSheet()
            }
        }
    }

    // MARK: - Columns

    @ViewBuilder
    private func leadingColumn(
        summary: InsightsStore.Summary, statuses: [DayLimitStatus]
    ) -> some View {
        heroCard(summary: summary)
            .padding(.top, 8)

        if checklist.isVisible {
            // The checklist owns every setup nag while it's up — no pill
            // double-teaming the location row.
            SetupChecklistCard(
                checklist: checklist,
                onLocation: { fixLocation() },
                onHome: { router.showHomePicker = true },
                onPhotos: { router.open(tab: .settings, settings: .timeMachine) },
                onTimeline: { router.open(tab: .settings, settings: .importTimeline) }
            )
        } else if let limitation = trackingLimitation {
            HStack {
                TrackingStatusPill(status: limitation) {
                    if limitation == .off {
                        openSystemSettings()
                    } else {
                        showAlwaysSheet = true
                    }
                }
                Spacer()
            }
        }

        if let heroYear {
            wrappedHeroCard(year: heroYear)
        }

        LimitsSummarySection(statuses: statuses, warnings: limitWarnings(statuses)) {
            router.openLimits()
        }
    }

    @ViewBuilder
    private func trailingColumn(summary: InsightsStore.Summary) -> some View {
        yearCard
            .padding(.top, isWide ? 8 : 0)

        PeriodChips(selection: $period)
            .padding(.top, 4)

        statsRow

        topCountries

        if !summary.stamps.isEmpty {
            InsightsCarousel(summary: summary) {
                router.open(tab: .passport)
            }
        }

        wrappedRows

        if store.currentStay() == nil && !checklist.isVisible {
            waitingCard
        }
    }

    /// Forecasts that would break a ceiling, keyed by rule.
    private func limitWarnings(_ statuses: [DayLimitStatus]) -> [String: DayLimitForecast] {
        // Reading the plans makes this view follow them.
        guard !AppContainer.shared.planStore.plans.isEmpty else { return [:] }
        var result: [String: DayLimitForecast] = [:]
        for status in statuses where status.rule.goal == .stayUnder {
            if let forecast = limits.forecast(for: status.rule, using: store), forecast.level == .over {
                result[status.id] = forecast
            }
        }
        return result
    }

    // MARK: - Hero and year

    private func heroCard(summary: InsightsStore.Summary) -> some View {
        let stay = store.currentStay()
        let lifetime = stay.flatMap { current in
            summary.stamps.first { $0.code == current.countryCode }?.totalDays
        } ?? 0
        let isHome = stay?.countryCode == store.homeCountry
        let daysThisYear = stay.map { store.daysThisYear(in: $0.countryCode) } ?? 0
        let activeLimit = limits.activeStatus(using: store)
        return Group {
            if Theme.isBold {
                HomeHeroBold(
                    stay: stay, isHome: isHome, daysThisYear: daysThisYear,
                    lifetimeDays: lifetime, activeLimit: activeLimit, model: heroGlobe
                )
            } else {
                HomeHeroCard(
                    stay: stay, isHome: isHome, daysThisYear: daysThisYear,
                    lifetimeDays: lifetime, activeLimit: activeLimit
                )
            }
        }
    }

    /// Repaint the globe when the visited set or the current country moves.
    private func refreshHero() async {
        guard Theme.isBold else { return }
        let visited = Set(insightsStore.summary(using: store).stamps.map(\.code))
        await heroGlobe.refresh(visited: visited, current: store.currentStay()?.countryCode)
    }

    /// This year as a heatmap. Tapping it opens the calendar it summarises.
    private var yearCard: some View {
        let today = store.todayEpoch
        let year = EpochDay(value: today).civil().year
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let days = store.resolvedDays(in: jan1...today)
        let tones = days.map { DayTone.tone(for: $0, home: store.homeOn($0.day)) }
        let stats = store.stats(in: jan1...today)
        return Button {
            router.open(tab: .calendar)
        } label: {
            YearHeatmapCard(
                year: year,
                tones: tones,
                travelDays: stats.travelDays,
                countries: stats.countriesVisited
            )
        }
        .buttonStyle(.plain)
    }

    private func wrappedHeroCard(year: Int) -> some View {
        Button {
            openWrapped(year: year)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Theme.auroraGradient)
                    .opacity(0.9)
                HStack(spacing: 14) {
                    MiniGlobe(size: 46, showsPlane: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR \(String(year)) IS READY")
                            .font(Theme.numeric(11, weight: .heavy))
                            .tracking(1.6)
                            .foregroundStyle(Theme.sky.opacity(0.75))
                        Text("Open your Year in Travel ✨")
                            .font(Theme.display(17, weight: .heavy))
                            .foregroundStyle(Theme.sky)
                    }
                    Spacer()
                    if buildingYear == year {
                        ProgressView().tint(Theme.sky)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.sky.opacity(0.8))
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .disabled(buildingYear != nil)
        .matchedTransitionSource(id: year, in: wrappedNS)
    }

    // MARK: - Year in Travel entry (plain row for now; the aurora card is W5)

    @ViewBuilder
    private var wrappedRows: some View {
        if !wrappedYears.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Year in Travel")

                ForEach(wrappedYears.filter { $0 != heroYear }, id: \.self) { year in
                    Button {
                        openWrapped(year: year)
                    } label: {
                        HStack(spacing: 11) {
                            Text("✨")
                                .font(.system(size: 20))
                            Text("Your \(String(year)) in Travel")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            if buildingYear == year {
                                ProgressView().tint(Theme.aurora1)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.ink3)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .nightCard()
                    }
                    .buttonStyle(.plain)
                    .disabled(buildingYear != nil)
                    .matchedTransitionSource(id: year, in: wrappedNS)
                }
            }
        }
    }

    private func openWrapped(year: Int) {
        guard buildingYear == nil else { return }
        buildingYear = year
        Task {
            if let data = await AppContainer.shared.wrappedBuilder.build(year: year) {
                UserDefaults.standard.set(true, forKey: "wrappedSeen-\(year)")
                presentedWrapped = WrappedPresentation(id: year, data: data)
            }
            buildingYear = nil
        }
    }

    private var periodRange: ClosedRange<Int> {
        period.range(today: store.todayEpoch, earliest: store.earliestDay)
    }

    private var statsRow: some View {
        let stats = store.stats(in: periodRange)
        return HStack(spacing: 10) {
            statTile(value: stats.countriesVisited, label: "Countries")
            statTile(value: stats.borderCrossings, label: "Crossings")
            statTile(value: stats.travelDays, label: "Travel days")
        }
    }

    private func statTile(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(Theme.isBold ? Theme.poster(40) : Theme.display(24, weight: .heavy))
                .foregroundStyle(Theme.auroraGradient)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(Theme.label(9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .nightCard()
    }

    private var topCountries: some View {
        let stats = store.stats(in: periodRange)
        let ranked = stats.daysPerCountry.sorted {
            ($0.value, $1.key) > ($1.value, $0.key)
        }
        let maxDays = ranked.first?.value ?? 1

        return VStack(alignment: .leading, spacing: 8) {
            if !ranked.isEmpty {
                SectionLabel(
                    title: "Your top",
                    actionTitle: ranked.count > 5 ? "All \(ranked.count)" : nil,
                    action: ranked.count > 5 ? { router.openWorld(.countries) } : nil
                )
            }

            ForEach(ranked.prefix(5), id: \.key) { code, days in
                NavigationLink(value: code) {
                    HStack(spacing: 11) {
                        FlagChip(code: code, size: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(countryName(code))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                if code == store.homeCountry {
                                    Text("HOME")
                                        .font(Theme.numeric(8, weight: .heavy))
                                        .foregroundStyle(Theme.amber)
                                }
                                Spacer()
                                Text("\(days)d")
                                    .font(Theme.figure(13, weight: .bold))
                                    .foregroundStyle(Theme.aurora1)
                                    .contentTransition(.numericText())
                            }
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Theme.hairline)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Theme.auroraGradient)
                                            .frame(width: geo.size.width * CGFloat(days) / CGFloat(maxDays))
                                    }
                            }
                            .frame(height: 3)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .nightCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Checklist location row: the next sensible step for wherever auth is.
    private func fixLocation() {
        if !location.smartTrackingEnabled {
            location.smartTrackingEnabled = true
        }
        switch location.authorizationStatus {
        case .notDetermined: location.requestWhenInUse()
        case .authorizedWhenInUse: showAlwaysSheet = true
        case .denied, .restricted: openSystemSettings()
        default: break
        }
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Waiting for your first location")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            } icon: {
                Image(systemName: "location.viewfinder")
                    .foregroundStyle(Theme.aurora1)
                    .symbolEffect(.pulse)
            }
            Text("Keep the app installed and carry on with your day — the first significant-location event arrives on its own. Or rebuild your past from photos in Settings → Time Machine.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
