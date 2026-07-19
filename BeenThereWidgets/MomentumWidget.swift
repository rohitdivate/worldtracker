import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Momentum" — days since your last NEW country, plus the next
/// %-of-the-world milestone. A gentle itch to go somewhere.
struct MomentumWidgetView: View {
    var entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let lastNewDay = snapshot.lastNewCountryDay {
                content(snapshot: snapshot, lastNewDay: lastNewDay)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://map"))
    }

    private func content(snapshot: WidgetSnapshot, lastNewDay: Int) -> some View {
        let todayEpoch = EpochDay(date: entry.date, timeZone: TimeZone.current).value
        let daysSince = max(0, todayEpoch - lastNewDay)
        // Long droughts turn amber — the nudge.
        let accent: Color = daysSince > 180 ? WTheme.amber : WTheme.aurora1

        return VStack(alignment: .leading, spacing: 0) {
            Text("LAST NEW COUNTRY")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(daysSince)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(daysSince == 1 ? "day ago" : "days ago")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WTheme.ink2)
            }

            Spacer(minLength: 2)

            if let milestone = milestoneLine(snapshot) {
                Text(milestone)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WTheme.ink2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// "3 more to 10% of the world" — the next 5%-of-195 step.
    private func milestoneLine(_ snapshot: WidgetSnapshot) -> String? {
        guard let count = snapshot.allTimeCountries, count > 0 else { return nil }
        let percent = Double(count) / 195.0 * 100
        let nextStep = (Int(percent / 5) + 1) * 5
        guard nextStep <= 100 else { return "\(count) countries — the whole map" }
        let needed = Int((Double(nextStep) / 100 * 195).rounded(.up)) - count
        guard needed > 0 else { return nil }
        return "\(needed) more \(needed == 1 ? "country" : "countries") to \(nextStep)% of the world"
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("MOMENTUM")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(WTheme.aurora1)
            Spacer()
            Text("🧭").font(.system(size: 26))
            Text(entry.snapshot == nil
                 ? widgetEmptyMessage
                 : "Log your first country to start the clock")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MomentumWidget: Widget {
    let kind = "MomentumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            MomentumWidgetView(entry: entry)
        }
        .configurationDisplayName("Momentum")
        .description("Days since your last new country, and your next milestone.")
        .supportedFamilies([.systemSmall])
    }
}
