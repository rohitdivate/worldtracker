import ActivityKit
import SwiftUI
import WidgetKit
import WorldTrackerKit

/// The trip banner: lock-screen card + Dynamic Island while you're abroad.
/// Rendered per the approved Night Flight mockups.
struct TravelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TravelActivityAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        auroraFlag(context.attributes.countryCode, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(widgetCountryName(context.attributes.countryCode))
                                .font(WTheme.figure(14, weight: .heavy))
                                .foregroundStyle(WTheme.ink)
                                .lineLimit(1)
                            Text("Day \(max(1, context.state.dayOfStay))")
                                .font(WTheme.figure(11, weight: .bold))
                                .foregroundStyle(WTheme.amber)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(context.state.daysThisYear)d")
                            .font(WTheme.figure(14, weight: .heavy))
                            .foregroundStyle(WTheme.aurora1)
                        Text("this year")
                            .font(.system(size: 9))
                            .foregroundStyle(WTheme.ink2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.limitFraction != nil {
                        limitBar(context.state)
                            .padding(.top, 4)
                    } else {
                        tripDots(count: context.state.countriesThisYear)
                            .padding(.top, 2)
                    }
                }
            } compactLeading: {
                Text(flagEmoji(context.attributes.countryCode))
                    .font(.system(size: 15))
            } compactTrailing: {
                // On the clock for a limit: the days left matter more than
                // the day count.
                if let used = context.state.limitUsed, let max = context.state.limitMax {
                    Text("\(Swift.max(0, max - used))d")
                        .font(WTheme.figure(12, weight: .heavy))
                        .foregroundStyle(WLevel.color(context.state.limitLevel))
                } else {
                    Text("D\(max(1, context.state.dayOfStay))")
                        .font(WTheme.figure(12, weight: .heavy))
                        .foregroundStyle(WTheme.aurora1)
                }
            } minimal: {
                Text(flagEmoji(context.attributes.countryCode))
                    .font(.system(size: 13))
            }
            .widgetURL(URL(string: "beenthere://home"))
            .keylineTint(WTheme.aurora1)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<TravelActivityAttributes>) -> some View {
        VStack(spacing: 10) {
            lockScreenRow(context)
            if context.state.limitFraction != nil {
                limitBar(context.state)
            }
        }
        .padding(14)
        .activityBackgroundTint(WTheme.sky.opacity(0.92))
        .activitySystemActionForegroundColor(WTheme.aurora1)
        .widgetURL(URL(string: "beenthere://home"))
    }

    /// "Schengen 90/180 ▓▓▓░░ 34/90 · 56 days left"
    private func limitBar(_ state: TravelActivityAttributes.ContentState) -> some View {
        let tint = WLevel.color(state.limitLevel)
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(state.limitName ?? "Day limit")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WTheme.ink2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(state.limitUsed ?? 0)/\(state.limitMax ?? 0) · \(state.limitHeadline ?? "")")
                    .font(WTheme.figure(11, weight: .heavy))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            WBar(fraction: state.limitFraction ?? 0, height: 4, tint: tint)
        }
    }

    private func lockScreenRow(_ context: ActivityViewContext<TravelActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            auroraFlag(context.attributes.countryCode, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("YOU'RE IN")
                    .font(WTheme.label(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(WTheme.aurora1)
                Text(widgetCountryName(context.attributes.countryCode))
                    .font(WTheme.figure(19, weight: .heavy))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                tripDots(count: context.state.countriesThisYear)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Day \(max(1, context.state.dayOfStay))")
                    .font(WTheme.figure(17, weight: .heavy))
                    .foregroundStyle(WTheme.amber)
                Text("\(context.state.daysThisYear)d this year")
                    .font(.system(size: 10.5))
                    .foregroundStyle(WTheme.ink2)
                WTheme.Wordmark()
                    .padding(.top, 1)
            }
        }
    }

    /// Flag in the aurora ring — the mockups' signature mark.
    private func auroraFlag(_ code: String, size: CGFloat) -> some View {
        Text(flagEmoji(code))
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(WTheme.card, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(WTheme.auroraGradient, lineWidth: 1.6)
            )
            .shadow(color: WTheme.aurora1.opacity(0.35), radius: 6)
    }

    /// One dot per country this year (capped) — the year's rhythm at a glance.
    private func tripDots(count: Int) -> some View {
        HStack(spacing: 3.5) {
            ForEach(0..<min(count, 10), id: \.self) { _ in
                Circle()
                    .fill(WTheme.aurora1)
                    .frame(width: 4, height: 4)
            }
            if count > 10 {
                Text("+\(count - 10)")
                    .font(WTheme.figure(8, weight: .bold))
                    .foregroundStyle(WTheme.ink3)
            }
        }
    }
}
