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
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(WTheme.ink)
                                .lineLimit(1)
                            Text("Day \(max(1, context.state.dayOfStay))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(WTheme.amber)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(context.state.daysThisYear)d")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(WTheme.aurora1)
                        Text("this year")
                            .font(.system(size: 9))
                            .foregroundStyle(WTheme.ink2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    tripDots(count: context.state.countriesThisYear)
                        .padding(.top, 2)
                }
            } compactLeading: {
                Text(flagEmoji(context.attributes.countryCode))
                    .font(.system(size: 15))
            } compactTrailing: {
                Text("D\(max(1, context.state.dayOfStay))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.aurora1)
            } minimal: {
                Text(flagEmoji(context.attributes.countryCode))
                    .font(.system(size: 13))
            }
            .widgetURL(URL(string: "beenthere://home"))
            .keylineTint(WTheme.aurora1)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<TravelActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            auroraFlag(context.attributes.countryCode, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("YOU'RE IN")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(WTheme.aurora1)
                Text(widgetCountryName(context.attributes.countryCode))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                tripDots(count: context.state.countriesThisYear)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Day \(max(1, context.state.dayOfStay))")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.amber)
                Text("\(context.state.daysThisYear)d this year")
                    .font(.system(size: 10.5))
                    .foregroundStyle(WTheme.ink2)
            }
        }
        .padding(14)
        .activityBackgroundTint(WTheme.sky.opacity(0.92))
        .activitySystemActionForegroundColor(WTheme.aurora1)
        .widgetURL(URL(string: "beenthere://home"))
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
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.ink3)
            }
        }
    }
}
