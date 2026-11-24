import SwiftUI
import WorldTrackerKit

/// One rule in full: the gauge, the window day by day, which countries the
/// days came from, and a planner for the next trip.
struct DayLimitDetailView: View {
    let ruleID: String

    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var reportURL: URL?
    @State private var arrival = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var limits: DayLimitStore { AppContainer.shared.dayLimitStore }

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        let _ = store.changeToken
        let _ = AppContainer.shared.planStore.plans   // the forecast follows the plans
        ZStack {
            Theme.sky.ignoresSafeArea()

            if let status = limits.status(id: ruleID, using: store) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if isWide {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 14) {
                                    gaugeCard(status)
                                    forecastCard(status)
                                    factsCard(status)
                                    historyCard(status)
                                }
                                .frame(maxWidth: .infinity)
                                VStack(spacing: 14) {
                                    windowCard(status)
                                    breakdownCard(status)
                                    if status.rule.goal == .stayUnder {
                                        plannerCard(status)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            gaugeCard(status)
                            forecastCard(status)
                            factsCard(status)
                            windowCard(status)
                            breakdownCard(status)
                            historyCard(status)
                            if status.rule.goal == .stayUnder {
                                plannerCard(status)
                            }
                        }
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete this limit")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.alert)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, isWide ? 28 : 18)
                    .padding(.top, 6)
                }
                .navigationTitle(status.rule.name)
                .sheet(isPresented: $showEditor) {
                    DayLimitEditorView(rule: status.rule)
                }
            } else {
                ContentUnavailableView(
                    "Limit removed",
                    systemImage: "gauge.with.dots.needle.0percent",
                    description: Text("This rule no longer exists.")
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Edit limit", systemImage: "pencil")
                    }
                    if let reportURL {
                        ShareLink(item: reportURL) {
                            Label("Export report (CSV)", systemImage: "tablecells")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.aurora1)
                }
                .accessibilityLabel("More")
            }
        }
        .task(id: store.changeToken) {
            reportURL = limits.rules.first { $0.id == ruleID }
                .flatMap { AppContainer.shared.exportService.exportLimitReport(for: $0) }
        }
        .confirmationDialog("Delete this limit?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                limits.remove(id: ruleID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the rule is removed. Your travel history is untouched.")
        }
    }

    // MARK: - Gauge

    private func gaugeCard(_ status: DayLimitStatus) -> some View {
        VStack(spacing: 14) {
            RingGauge(fraction: status.fraction, lineWidth: 15, tint: status.tint) {
                VStack(spacing: 0) {
                    Text("\(status.used)")
                        .font(Theme.isBold ? Theme.poster(64) : Theme.display(46, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("of \(status.rule.limit) days")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .frame(width: 168, height: 168)
            .padding(.top, 6)

            VStack(spacing: 5) {
                Label(status.headline, systemImage: status.level.symbol)
                    .font(Theme.display(20, weight: .heavy))
                    .foregroundStyle(status.level.color)
                Text(status.outlook)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(DayLimitCopy.sentence(for: status.rule))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .nightCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Facts

    private func factsCard(_ status: DayLimitStatus) -> some View {
        let year = EpochDay(value: status.asOf).civil().year
        let windowText = DayFormat.shortRange(
            status.window.lowerBound, status.window.upperBound, todayYear: year
        ).capitalized
        return VStack(spacing: 0) {
            fact("Window", windowText)
            divider
            fact(
                status.rule.window.isRolling ? "Type" : "Resets in",
                status.rule.window.isRolling
                    ? "Rolling, moves every day"
                    : "\(status.daysUntilReset ?? 0) days"
            )
            divider
            fact("Counting today", status.countsToday ? "Yes" : "No",
                 tint: status.countsToday ? status.level.color : Theme.ink2)
            if status.unknownDays > 0 {
                divider
                NavigationLink(
                    value: AppRouter.HomeRoute.gaps(status.window.lowerBound, status.asOf)
                ) {
                    HStack(alignment: .top) {
                        fact(
                            "Days with no data",
                            "\(status.unknownDays)",
                            tint: Theme.amber,
                            footnote: "Not counted either way. Review them for an exact figure."
                        )
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                            .padding(.top, 14)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .nightCard()
    }

    // MARK: - Forecast and history

    /// Where the planned trips leave this rule. Hidden with no plans.
    @ViewBuilder
    private func forecastCard(_ status: DayLimitStatus) -> some View {
        if let forecast = limits.forecast(for: status.rule, using: store) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "With your planned trips")
                    .padding(.top, -6)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(forecast.peakUsed)")
                        .font(Theme.isBold ? Theme.poster(44) : Theme.display(32, weight: .heavy))
                        .foregroundStyle(forecast.level.color)
                    Text("of \(status.rule.limit) at the peak, on \(DayFormat.long(forecast.peakDay))")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                }
                ProgressBar(
                    fraction: Double(forecast.peakUsed) / Double(max(1, status.rule.limit)),
                    height: 6, tint: AnyShapeStyle(forecast.level.color)
                )
                Label(forecastVerdict(forecast, rule: status.rule), systemImage: forecast.level.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(forecast.level.color)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nightCard()
            .accessibilityElement(children: .combine)
        }
    }

    private func forecastVerdict(_ forecast: DayLimitForecast, rule: DayLimitRule) -> String {
        switch rule.goal {
        case .stayUnder:
            if let day = forecast.crossingDay {
                return "Goes over the limit on \(DayFormat.long(day))"
            }
            let spare = rule.limit - forecast.peakUsed
            return "Stays inside the limit, with \(spare) \(spare == 1 ? "day" : "days") to spare"
        case .reachAtLeast:
            if let day = forecast.crossingDay {
                return "Reaches the target on \(DayFormat.long(day))"
            }
            return "Still \(rule.limit - forecast.peakUsed) short after your plans"
        }
    }

    /// How the rule has stood before: the all-time high for a rolling
    /// window, or the totals for each past year for a fixed one.
    @ViewBuilder
    private func historyCard(_ status: DayLimitStatus) -> some View {
        let todayYear = EpochDay(value: status.asOf).civil().year
        if let peak = limits.peak(for: status.rule, using: store) {
            VStack(spacing: 0) {
                fact(
                    "Highest ever",
                    "\(peak.used) of \(status.rule.limit)",
                    tint: peak.used > status.rule.limit && status.rule.goal == .stayUnder
                        ? Theme.alert : Theme.ink,
                    footnote: "In the \(status.rule.windowLabel) ending \(DayFormat.long(peak.day))"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .nightCard()
        } else {
            // Years from before anything was counted are just noise.
            let all = limits.pastWindows(for: status.rule, using: store)
            let windows = Array(all.prefix((all.lastIndex { $0.used > 0 } ?? 0) + 1))
            if windows.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(title: "Year by year")
                        .padding(.top, -6)
                    ForEach(windows) { window in
                        HStack(spacing: 10) {
                            Text(DayFormat.shortRange(
                                window.window.lowerBound, window.window.upperBound, todayYear: todayYear + 99
                            ))
                            .font(Theme.numeric(11, weight: .medium))
                            .foregroundStyle(window.isCurrent ? Theme.ink : Theme.ink2)
                            .frame(width: 168, alignment: .leading)
                            ProgressBar(
                                fraction: Double(window.used) / Double(max(1, status.rule.limit)),
                                height: 4,
                                tint: AnyShapeStyle(
                                    window.used > status.rule.limit && status.rule.goal == .stayUnder
                                        ? Theme.alert : Theme.ink
                                )
                            )
                            Text("\(window.used)")
                                .font(Theme.figure(12, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
                .padding(16)
                .nightCard()
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    private func fact(
        _ label: String, _ value: String, tint: Color = Theme.ink, footnote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink2)
                Spacer()
                Text(value)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.vertical, 11)
    }

    // MARK: - Window, day by day

    private enum CellKind { case counted, other, unknown, future }

    private func cells(_ status: DayLimitStatus) -> [CellKind] {
        let days = store.resolvedDays(in: limits.historyRange(today: status.asOf))
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) })
        return status.window.map { day in
            if day > status.asOf { return .future }
            guard let resolved = byDay[day], !resolved.countryCodes.isEmpty else { return .unknown }
            return status.rule.scope.counts(resolved.countryCodes) ? .counted : .other
        }
    }

    private func windowCard(_ status: DayLimitStatus) -> some View {
        let kinds = cells(status)
        let columns = Int((Double(kinds.count) / 7).rounded(.up))
        let tint = status.level.color

        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "The window, day by day")
                .padding(.top, -6)

            Canvas { context, size in
                let cell = size.width / CGFloat(max(1, columns))
                let square = cell * 0.78
                let inset = (cell - square) / 2
                for (index, kind) in kinds.enumerated() {
                    let rect = CGRect(
                        x: CGFloat(index / 7) * cell + inset,
                        y: CGFloat(index % 7) * cell + inset,
                        width: square, height: square
                    )
                    let color: Color
                    switch kind {
                    case .counted: color = tint
                    case .other: color = Theme.ink3.opacity(0.38)
                    case .unknown: color = Theme.ink3.opacity(0.14)
                    case .future: color = Theme.ink3.opacity(0.06)
                    }
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: square * 0.26),
                        with: .color(color)
                    )
                }
            }
            .aspectRatio(CGFloat(max(1, columns)) / 7, contentMode: .fit)

            HStack(spacing: 12) {
                key(tint, "Counted")
                key(Theme.ink3.opacity(0.38), "Not counted")
                key(Theme.ink3.opacity(0.14), "No data")
                Spacer()
                Text("Oldest → newest")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(16)
        .nightCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.used) counted days in the window")
    }

    private func key(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
        }
    }

    // MARK: - Where the days came from

    @ViewBuilder
    private func breakdownCard(_ status: DayLimitStatus) -> some View {
        let rows = breakdown(status)
        if rows.count > 1 || (rows.count == 1 && !isSingleCountry(status.rule.scope)) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "Where the days came from")
                    .padding(.top, -6)
                let top = rows.first?.days ?? 1
                ForEach(rows.prefix(8), id: \.code) { row in
                    HStack(spacing: 10) {
                        Text(flagEmoji(row.code)).font(.system(size: 20))
                        Text(countryName(row.code))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .frame(width: 118, alignment: .leading)
                        ProgressBar(fraction: Double(row.days) / Double(top), height: 4)
                        Text("\(row.days)d")
                            .font(Theme.numeric(12, weight: .bold))
                            .foregroundStyle(Theme.aurora1)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .nightCard()
        }
    }

    private func isSingleCountry(_ scope: DayLimitScope) -> Bool {
        if case .country = scope { return true }
        return false
    }

    /// Counted days in the window, credited to each country present.
    private func breakdown(_ status: DayLimitStatus) -> [(code: String, days: Int)] {
        let days = store.resolvedDays(in: limits.historyRange(today: status.asOf))
        var totals: [String: Int] = [:]
        for day in days
        where status.window.contains(day.day) && status.rule.scope.counts(day.countryCodes) {
            for code in day.countryCodes {
                switch status.rule.scope {
                case .schengen where !SchengenArea.members.contains(code): continue
                case .country(let only) where code != only: continue
                default: totals[code, default: 0] += 1
                }
            }
        }
        return totals
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map { (code: $0.key, days: $0.value) }
    }

    // MARK: - Planner

    private func plannerCard(_ status: DayLimitStatus) -> some View {
        let entry = EpochDay(date: arrival, timeZone: .current).value
        let stay = limits.maxStay(rule: status.rule, entryDay: entry, using: store)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Plan a trip")
                .padding(.top, -6)

            DatePicker("Arriving", selection: $arrival, in: tomorrow..., displayedComponents: .date)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Theme.ink)
                .tint(Theme.aurora2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let stay {
                    Text("\(stay)")
                        .font(Theme.display(34, weight: .heavy))
                        .foregroundStyle(stay > 0 ? AnyShapeStyle(Theme.auroraGradient) : AnyShapeStyle(Theme.alert))
                        .contentTransition(.numericText())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stay == 1 ? "day available" : "days available")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(stay > 0
                             ? "Leave by \(DayFormat.long(entry + stay - 1))"
                             : "Nothing free on that date yet")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink3)
                    }
                } else {
                    Text("No ceiling in reach from that date")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
            }
            .animation(.snappy, value: stay)

            Text("Assumes no counted days between now and the arrival.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
        }
        .padding(16)
        .nightCard()
    }
}
