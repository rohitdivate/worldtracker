import SwiftUI
import WorldTrackerKit

/// The calendar of flags: infinitely scrolling month grids where every day
/// wears the flag of where you were. Split flags mark border-crossing days,
/// dotted cells are gap-filled inferences, amber ring is today.
struct SelectedDay: Identifiable {
    let epochDay: Int
    var id: Int { epochDay }
}

struct HistoryView: View {
    @State private var selectedDay: SelectedDay?
    @State private var viewMode: ViewMode = .calendar
    @State private var showTripEditor = false

    enum ViewMode: String, CaseIterable {
        case calendar = "Calendar"
        case list = "Trips"
    }

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sky.ignoresSafeArea()

                if viewMode == .calendar {
                    calendarBody
                } else {
                    TripListView()
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showTripEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.aurora1)
                    }
                }
            }
            .sheet(isPresented: $showTripEditor) {
                TripEditorView()
            }
            .navigationDestination(for: String.self) { code in
                CountryDetailView(countryCode: code)
            }
            .navigationDestination(for: TripSegment.self) { segment in
                TripDetailView(segment: segment)
            }
            .sheet(item: $selectedDay) { selection in
                DayEditorView(epochDay: selection.epochDay)
                    .presentationDetents([.large])
                    .presentationBackground(Theme.skyRaised)
            }
        }
    }

    private var calendarBody: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                if store.earliestDay == nil {
                    EmptyStateCTAs(
                        icon: "calendar.badge.plus",
                        title: "Your calendar is waiting",
                        message: "Every day you travel gets a flag. Fill in the past right now — no waiting required."
                    )
                    .padding(.top, 8)
                }
                legend
                    .padding(.top, 4)
                // Newest month first: "now" lives at the top, so the system
                // double-tap-the-tab scroll-to-top gesture jumps to today —
                // not to some EXIF-glitch month in the year 2000.
                ForEach(months.reversed()) { month in
                    MonthGridView(month: month) { day in
                        selectedDay = SelectedDay(epochDay: day)
                    }
                }
                Spacer(minLength: 90)
            }
            .padding(.horizontal, 16)
        }
        .defaultScrollAnchor(.top)
    }

    /// Months from the earliest recorded fact (min 6 months back) to now.
    private var months: [MonthSpec] {
        _ = store.changeToken  // re-render when the ledger changes
        let today = store.todayEpoch
        let (nowYear, nowMonth, _) = EpochDay(value: today).civil()

        var startYear = nowYear
        var startMonth = nowMonth - 5
        if let earliest = store.earliestDay {
            let (y, m, _) = EpochDay(value: earliest).civil()
            if y < startYear || (y == startYear && m < startMonth) {
                startYear = y
                startMonth = m
            }
        }
        while startMonth < 1 {
            startMonth += 12
            startYear -= 1
        }

        var specs: [MonthSpec] = []
        var year = startYear
        var month = startMonth
        while year < nowYear || (year == nowYear && month <= nowMonth) {
            specs.append(MonthSpec(year: year, month: month))
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        }
        return specs
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.aurora1, label: "Tracked")
            legendItem(color: Theme.aurora2, label: "From photos")
            legendItem(color: Theme.amber, label: "Today")
            HStack(spacing: 5) {
                SplitFlagChip(first: "GB", second: "FR", size: 14)
                Text("Border day").font(.system(size: 10)).foregroundStyle(Theme.ink3)
            }
        }
        .padding(.top, 6)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.ink3)
        }
    }
}

/// One calendar month, addressed purely by civil (year, month) — no Date math.
struct MonthSpec: Identifiable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }

    var firstEpochDay: Int {
        EpochDay.daysFromCivil(year: year, month: month, day: 1)
    }

    var dayCount: Int {
        let nextYear = month == 12 ? year + 1 : year
        let nextMonth = month == 12 ? 1 : month + 1
        return EpochDay.daysFromCivil(year: nextYear, month: nextMonth, day: 1) - firstEpochDay
    }

    /// Leading blanks for a Monday-first grid. 1970-01-01 was a Thursday
    /// (index 3 in a Monday-first week).
    var leadingBlanks: Int {
        (((firstEpochDay + 3) % 7) + 7) % 7
    }

    var title: String {
        let formatter = DateFormatter()
        let name = formatter.monthSymbols[month - 1]
        return name
    }
}

struct MonthGridView: View {
    let month: MonthSpec
    let onSelect: (Int) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private static let dowSymbols = ["M", "T", "W", "T", "F", "S", "S"]

    @State private var rippleOrigin: CGPoint = .zero
    @State private var rippleTrigger = 0
    @State private var shareItem: ShareItem?

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let range = month.firstEpochDay...(month.firstEpochDay + month.dayCount - 1)
        let days = store.resolvedDays(in: range)
        let today = store.todayEpoch
        let hasData = days.contains { !$0.countryCodes.isEmpty }

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(month.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(String(month.year))
                    .font(Theme.numeric(12, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                Spacer()
                if hasData {
                    Button {
                        shareMonth(days: days, today: today)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: Self.columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Self.dowSymbols[i])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                ForEach(0..<month.leadingBlanks, id: \.self) { i in
                    Color.clear
                        .frame(height: 44)
                        .id("blank-\(i)")
                }
                ForEach(days, id: \.day) { day in
                    DayCellView(
                        resolved: day,
                        dayNumber: day.day - month.firstEpochDay + 1,
                        isToday: day.day == today,
                        isFuture: day.day > today
                    )
                    .onTapGesture(coordinateSpace: .named("monthGrid")) { location in
                        guard day.day <= today else { return }
                        rippleOrigin = location
                        rippleTrigger += 1
                        onSelect(day.day)
                    }
                }
            }
            .coordinateSpace(.named("monthGrid"))
            .rippleEffect(at: rippleOrigin, trigger: rippleTrigger)
        }
        .padding(14)
        .nightCard()
        .sheet(item: $shareItem) { item in
            SharePreviewSheet(url: item.url)
        }
    }

    /// Render the month card on tap — never eagerly for every scrolled month.
    private func shareMonth(days: [ResolvedDay], today: Int) {
        let timeline = store.homeTimeline
        var countries: [String] = []
        var travelDays = 0
        for day in days {
            let home = timeline.home(on: day.day)
            for code in day.countryCodes where code != home && !countries.contains(code) {
                countries.append(code)
            }
            if day.countryCodes.contains(where: { $0 != home }) { travelDays += 1 }
        }
        guard let url = ShareCardService.render(
            MonthShareCard(
                month: month,
                days: days,
                todayEpoch: today,
                countries: countries,
                travelDays: travelDays
            ),
            name: "BeenThere-\(month.year)-\(String(format: "%02d", month.month))"
        ) else { return }
        shareItem = ShareItem(url: url)
    }
}

struct DayCellView: View {
    let resolved: ResolvedDay
    let dayNumber: Int
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 8.5, weight: isToday ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isToday ? Theme.amber : Theme.ink3)

            if isFuture {
                Circle().fill(Theme.ink3.opacity(0.4)).frame(width: 3, height: 3)
            } else if resolved.countryCodes.count >= 2 {
                SplitFlagChip(first: resolved.countryCodes[0], second: resolved.countryCodes[1], size: 18)
            } else if let code = resolved.countryCodes.first {
                Text(flagEmoji(code)).font(.system(size: 14))
            } else {
                Circle()
                    .strokeBorder(Theme.ink3.opacity(0.35), lineWidth: 1)
                    .frame(width: 5, height: 5)
            }

            if resolved.hasNote {
                Circle().fill(Theme.amber).frame(width: 3, height: 3)
            } else {
                Color.clear.frame(width: 3, height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.card.opacity(isFuture ? 0.18 : 0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, style: StrokeStyle(
                    lineWidth: isToday ? 1.5 : 1,
                    dash: resolved.isFilled ? [3, 2.5] : []
                ))
        )
        .opacity(isFuture ? 0.45 : 1)
    }

    private var borderColor: Color {
        if isToday { return Theme.amber }
        if resolved.isFilled { return Theme.aurora2.opacity(0.5) }
        switch resolved.source {
        case .photo: return Theme.aurora2.opacity(0.35)
        case .importedTimeline, .importedFlight: return Theme.aurora2.opacity(0.3)
        case .manual: return Theme.amber.opacity(0.4)
        case .gps, .visit: return Theme.aurora1.opacity(0.25)
        case .timezoneHint: return Theme.ink3.opacity(0.3)
        case nil: return Theme.hairline
        }
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
