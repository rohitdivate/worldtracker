import SwiftUI
import WorldTrackerKit

/// Home's "Day limits" block: up to three live gauges, or the pitch for the
/// feature when no rule exists yet.
struct LimitsSummarySection: View {
    let statuses: [DayLimitStatus]
    var warnings: [String: DayLimitForecast] = [:]
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(
                title: "Day limits",
                actionTitle: statuses.isEmpty ? nil : "Manage",
                action: statuses.isEmpty ? nil : onManage
            )

            if statuses.isEmpty {
                pitch
            } else {
                ForEach(statuses.prefix(3)) { status in
                    NavigationLink(value: AppRouter.HomeRoute.limit(status.id)) {
                        // Home stays quiet: a forecast only shows here when
                        // the plans would break the limit.
                        LimitRow(status: status, forecast: warnings[status.id])
                    }
                    .buttonStyle(.plain)
                }
                if statuses.count > 3 {
                    Button(action: onManage) {
                        Text("\(statuses.count - 3) more")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.aurora1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pitch: some View {
        Button(action: onManage) {
            HStack(spacing: 13) {
                IconTile(symbol: "gauge.with.dots.needle.67percent", size: 42, tint: Theme.aurora2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Count the days that matter")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Schengen 90/180, 183-day residency, UK absences. Counted from your history, automatically.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.auroraGradient)
            }
            .padding(14)
            .nightCard()
        }
        .buttonStyle(.plain)
    }
}

/// One rule as a row: ring, name, headline, what happens next.
struct LimitRow: View {
    let status: DayLimitStatus
    var showsOutlook = false
    /// Where the planned trips leave this rule, when there are any.
    var forecast: DayLimitForecast?

    var body: some View {
        HStack(spacing: 13) {
            RingGauge(fraction: status.fraction, lineWidth: 5, tint: status.tint) {
                Text("\(status.used)")
                    .font(Theme.numeric(13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(6)
            }
            .frame(width: 46, height: 46)

            // Name on its own line: rule names are long ("183 days in the
            // United Kingdom") and used to lose a third of the row to the
            // headline beside them.
            VStack(alignment: .leading, spacing: 3) {
                Text(status.rule.name)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 6) {
                    Text(status.headline)
                        .font(Theme.display(13.5, weight: .heavy))
                        .foregroundStyle(status.level.color)
                        .lineLimit(1)
                    if status.countsToday {
                        Text("COUNTING")
                            .font(Theme.numeric(7.5, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(status.level.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(
                                Capsule().strokeBorder(status.level.color.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                Text(showsOutlook ? status.outlook : status.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let forecast {
                    Label(forecast.summary(for: status.rule), systemImage: "calendar.badge.clock")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(forecast.level.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .nightCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.rule.name): \(status.headline). \(status.detail)")
    }
}

/// A sideways shelf of lifetime facts. Each card opens the Passport tab,
/// where the full versions live.
struct InsightsCarousel: View {
    let summary: InsightsStore.Summary
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Insights", actionTitle: "Passport", action: onOpen)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cards) { card in
                        Button(action: onOpen) { InsightCard(card: card) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var cards: [InsightCard.Model] {
        let insights = summary.insights
        var result: [InsightCard.Model] = []

        if insights.totalKm > 0 {
            let laps = Double(insights.totalKm) / Double(AchievementEngine.earthCircumferenceKm)
            result.append(.init(
                id: "km", symbol: "airplane", tint: Theme.aurora1,
                value: "\(insights.totalKm.grouped) km",
                caption: "between countries",
                footnote: String(format: "%.1f× around the world", laps)
            ))
        }
        if let farthest = insights.farthest {
            result.append(.init(
                id: "far", symbol: "location.north.line.fill", tint: Theme.aurora2,
                value: "\(flagEmoji(farthest.code)) \(farthest.km.grouped) km",
                caption: "farthest from home",
                footnote: countryName(farthest.code)
            ))
        }
        if let pace = insights.pace {
            let delta = pace.countriesThisYear - pace.countriesLastYear
            let sign = delta > 0 ? "+" : ""
            result.append(.init(
                id: "pace", symbol: "chart.line.uptrend.xyaxis", tint: Theme.amber,
                value: "\(sign)\(delta) \(abs(delta) == 1 ? "country" : "countries")",
                caption: "vs this point last year",
                footnote: "\(pace.travelDaysThisYear) travel days, was \(pace.travelDaysLastYear)"
            ))
        }
        if let trip = insights.longestAway {
            result.append(.init(
                id: "trip", symbol: "suitcase.fill", tint: Theme.aurora1,
                value: "\(trip.dayCount) days",
                caption: "longest trip",
                footnote: trip.countryCodes.prefix(5).map(flagEmoji).joined(separator: " ")
            ))
        }
        result.append(.init(
            id: "continents", symbol: "globe.europe.africa.fill", tint: Theme.aurora2,
            value: "\(summary.continentsVisited) of 7",
            caption: "continents",
            footnote: "\(summary.stamps.count) stamps collected"
        ))
        if let next = summary.nextAchievement {
            result.append(.init(
                id: "badge", symbol: next.symbol, tint: Theme.amber,
                value: next.title,
                caption: "next badge",
                footnote: "\(next.current.grouped) of \(next.target.grouped)"
            ))
        }
        return result
    }
}

struct InsightCard: View {
    struct Model: Identifiable {
        let id: String
        let symbol: String
        let tint: Color
        let value: String
        let caption: String
        let footnote: String
    }

    let card: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(symbol: card.symbol, size: 30, tint: card.tint)
            Spacer(minLength: 0)
            Text(card.value)
                .font(Theme.display(17, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(card.caption.uppercased())
                .font(Theme.label(8.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.ink3)
            Text(card.footnote)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(13)
        .frame(width: 152, height: 142, alignment: .leading)
        .nightCard()
        .accessibilityElement(children: .combine)
    }
}
