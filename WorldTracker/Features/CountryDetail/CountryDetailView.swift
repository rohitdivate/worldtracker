import SwiftUI
import WorldTrackerKit

/// One country's story: big flag, lifetime totals, trips grouped by year.
struct CountryDetailView: View {
    let countryCode: String

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var insightsStore: InsightsStore { AppContainer.shared.insightsStore }
    private var limits: DayLimitStore { AppContainer.shared.dayLimitStore }
    private var router: AppRouter { AppContainer.shared.router }

    /// First seen, last seen, continent: the stamp's facts in a row.
    @ViewBuilder
    private var stampFacts: some View {
        if let stamp = insightsStore.summary(using: store).stamps.first(where: { $0.code == countryCode }) {
            HStack(alignment: .top) {
                MetricColumn(value: DayFormat.monthYear(stamp.firstDay), label: "First seen", valueSize: 15)
                Spacer()
                MetricColumn(value: DayFormat.monthYear(stamp.lastDay), label: "Last seen", valueSize: 15)
                Spacer()
                MetricColumn(
                    value: stamp.continent?.displayName ?? "—", label: "Continent", valueSize: 15
                )
            }
            .padding(16)
            .nightCard()
        }
    }

    /// Day limits this country counts toward, with their live status.
    @ViewBuilder
    private var limitRows: some View {
        let relevant = limits.statuses(using: store).filter {
            switch $0.rule.scope {
            case .outside: return false
            default: return $0.rule.scope.counts([countryCode])
            }
        }
        if !relevant.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Day limits")
                ForEach(relevant) { status in
                    Button {
                        router.openLimits(ruleID: status.id)
                    } label: {
                        LimitRow(status: status)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var body: some View {
        let _ = store.changeToken
        let today = store.todayEpoch
        let earliest = store.earliestDay ?? today
        let allSegments = store.segments(in: min(earliest, today)...today)
            .filter { $0.countryCode == countryCode }
        let totalDays = allSegments.reduce(0) { $0 + $1.dayCount }
        let (todayYear, _, _) = EpochDay(value: today).civil()
        let byYear = Dictionary(grouping: allSegments) {
            EpochDay(value: $0.startDay).civil().year
        }

        ZStack {
            Theme.sky.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    FlagChip(code: countryCode, size: 76)
                        .shadow(color: Theme.aurora1.opacity(0.3), radius: 18)
                        .padding(.top, 10)

                    Text(countryName(countryCode))
                        .font(Theme.display(30, weight: .heavy))
                        .foregroundStyle(Theme.ink)

                    Text("\(allSegments.count) \(allSegments.count == 1 ? "TRIP" : "TRIPS") · \(totalDays) TOTAL DAYS")
                        .font(Theme.numeric(11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.aurora1)

                    stampFacts
                    limitRows

                    ForEach(byYear.keys.sorted(by: >), id: \.self) { year in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(year))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.ink2)

                            ForEach(byYear[year] ?? []) { segment in
                                NavigationLink(value: segment) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(segment.dayCount) \(segment.dayCount == 1 ? "day" : "days")")
                                                .font(Theme.figure(18, weight: .bold))
                                                .foregroundStyle(Theme.ink)
                                            Text(DayFormat.shortRange(segment.startDay, segment.endDay, todayYear: todayYear))
                                                .font(Theme.numeric(11, weight: .medium))
                                                .foregroundStyle(Theme.ink3)
                                        }
                                        Spacer()
                                        if segment.endDay >= today {
                                            Text("NOW")
                                                .font(Theme.numeric(9, weight: .heavy))
                                                .foregroundStyle(Theme.amber)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .strokeBorder(Theme.amber.opacity(0.5), lineWidth: 1.2)
                                                )
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.ink3)
                                    }
                                    .padding(14)
                                    .nightCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { CountryDetailView(countryCode: "ES") }
        .preferredColorScheme(.dark)
}
