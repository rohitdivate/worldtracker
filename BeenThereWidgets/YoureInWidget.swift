import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "You're In" — the flag under your feet, day of stay, days this year.
/// The approved small-widget design from the Night Flight widget deck.
struct YoureInWidgetView: View {
    var entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                accessoryCircular
            case .accessoryRectangular:
                accessoryRectangular
            default:
                if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                    content(snapshot: snapshot, code: code)
                } else {
                    waiting
                }
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular || family == .accessoryRectangular {
                AccessoryWidgetBackground()
            } else {
                WTheme.background
            }
        }
        .widgetURL(URL(string: "beenthere://home"))
    }

    // MARK: - Lock-screen accessories (system-tinted, so no custom colors)

    private var accessoryCircular: some View {
        VStack(spacing: 0) {
            if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                Text(flagEmoji(code)).font(.system(size: 20))
                Text("D\(max(1, snapshot.dayOfStay))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            } else {
                Text("🌍").font(.system(size: 22))
            }
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                Text("\(flagEmoji(code)) \(widgetCountryName(code))")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text("Day \(max(1, snapshot.dayOfStay)) of this stay")
                    .font(.system(size: 11))
                Text("\(snapshot.countriesThisYear) countries this year")
                    .font(.system(size: 11))
                    .opacity(0.7)
            } else {
                Text("Been There")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Text("Open the app to light this up")
                    .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func content(snapshot: WidgetSnapshot, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOU'RE IN")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(WTheme.aurora1)

            Spacer(minLength: 4)

            Text(flagEmoji(code))
                .font(.system(size: 34))
                .shadow(color: WTheme.aurora1.opacity(0.4), radius: 8)

            Text(widgetCountryName(code))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Text("Day \(max(1, snapshot.dayOfStay))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.amber)
                Text("· \(snapshot.daysThisYearInCurrent)d this year")
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BEEN THERE")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(WTheme.aurora1)
            Spacer()
            Text("🌍")
                .font(.system(size: 30))
            Text(widgetEmptyMessage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct YoureInWidget: Widget {
    let kind = "YoureInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            YoureInWidgetView(entry: entry)
        }
        .configurationDisplayName("You're In")
        .description("The country under your feet, at a glance.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
