import SwiftUI
import WorldTrackerKit

/// The top of Home: where you are, how long you've been there, and, when a
/// day limit is ticking for this country, how much of it is left.
struct HomeHeroCard: View {
    let stay: (countryCode: String, days: Int)?
    let isHome: Bool
    let daysThisYear: Int
    let lifetimeDays: Int
    let activeLimit: DayLimitStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("YOU'RE IN")
                    .font(Theme.label(11, weight: .bold))
                    .tracking(2.2)
                    .foregroundStyle(Theme.aurora1)
                Spacer()
                if stay != nil {
                    Text(isHome ? "HOME" : "AWAY")
                        .font(Theme.numeric(9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(isHome ? Theme.amber : Theme.aurora1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .overlay(
                            Capsule().strokeBorder(
                                (isHome ? Theme.amber : Theme.aurora1).opacity(0.5),
                                lineWidth: 1
                            )
                        )
                }
            }

            HStack(spacing: 14) {
                if let code = stay?.countryCode {
                    FlagChip(code: code, size: 62)
                        .shadow(color: Theme.aurora1.opacity(0.35), radius: 14)
                } else {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 62, height: 62)
                        .overlay(Text("🌍").font(.system(size: 32)))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(stay.map { countryName($0.countryCode) } ?? "Finding you…")
                        .font(Theme.display(28, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    if let stay {
                        Text(stay.days == 1 ? "Arrived today" : "Here since \(arrival(stay.days))")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }

            if let stay {
                Rectangle().fill(Theme.hairline).frame(height: 1)

                HStack(alignment: .top) {
                    MetricColumn(
                        value: "Day \(stay.days)", label: "This stay",
                        tint: AnyShapeStyle(Theme.auroraGradient)
                    )
                    Spacer()
                    MetricColumn(value: "\(daysThisYear)", label: "Days this year")
                    Spacer()
                    MetricColumn(value: lifetimeDays.grouped, label: "Days all time")
                }
            }

            if let limit = activeLimit {
                limitStrip(limit)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    /// The live limit for this country, as one line and a bar.
    private func limitStrip(_ status: DayLimitStatus) -> some View {
        NavigationLink(value: AppRouter.HomeRoute.limit(status.id)) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: status.level.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(status.level.color)
                    Text(status.rule.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text("\(status.used)/\(status.rule.limit) · \(status.headline)")
                        .font(Theme.numeric(11, weight: .bold))
                        .foregroundStyle(status.level.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                ProgressBar(fraction: status.fraction, tint: status.tint)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(status.level.color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(status.level.color.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func arrival(_ days: Int) -> String {
        let today = AppContainer.shared.ledgerStore.todayEpoch
        let year = EpochDay(value: today).civil().year
        return DayFormat.shortRange(today - days + 1, today - days + 1, todayYear: year).capitalized
    }
}
