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
            case .accessoryInline:
                accessoryInline
            case .systemMedium:
                if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                    medium(snapshot: snapshot, code: code)
                } else {
                    waiting
                }
            default:
                if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                    content(snapshot: snapshot, code: code)
                } else {
                    waiting
                }
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular || family == .accessoryRectangular
                || family == .accessoryInline {
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
                    .font(WTheme.figure(12, weight: .heavy))
            } else {
                Text("🌍").font(.system(size: 22))
            }
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                Text("\(flagEmoji(code)) \(widgetCountryName(code))")
                    .font(WTheme.figure(13, weight: .heavy))
                    .lineLimit(1)
                Text("Day \(max(1, snapshot.dayOfStay)) of this stay")
                    .font(.system(size: 11))
                Text("\(snapshot.countriesThisYear) countries this year")
                    .font(.system(size: 11))
                    .opacity(0.7)
            } else {
                Text("Been There")
                    .font(WTheme.figure(13, weight: .heavy))
                Text("Open the app to light this up")
                    .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One line beside the Lock Screen date: country, day, and the limit
    /// that is ticking if there is one.
    private var accessoryInline: some View {
        Group {
            if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                if let limit = snapshot.limits?.first(where: { $0.countsToday && $0.isCeiling }) {
                    Text("\(widgetCountryName(code)) · Day \(max(1, snapshot.dayOfStay)) · \(limit.headline)")
                } else {
                    Text("\(widgetCountryName(code)) · Day \(max(1, snapshot.dayOfStay))")
                }
            } else {
                Text("Been There")
            }
        }
    }

    /// Medium: the small widget on the left; on the right the limit this
    /// stay is counting toward, or the year so far when there isn't one.
    private func medium(snapshot: WidgetSnapshot, code: String) -> some View {
        HStack(spacing: 14) {
            content(snapshot: snapshot, code: code)

            Rectangle()
                .fill(WTheme.hairline2)
                .frame(width: 1)
                .padding(.vertical, 6)

            if let limit = snapshot.limits?.first(where: { $0.countsToday && $0.isCeiling }) {
                VStack(spacing: 6) {
                    WRing(fraction: limit.fraction, lineWidth: 7, tint: limit.color) {
                        VStack(spacing: -1) {
                            Text("\(limit.used)")
                                .font(WTheme.figure(20, weight: .heavy))
                                .foregroundStyle(WTheme.ink)
                            Text("of \(limit.limit)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(WTheme.ink3)
                        }
                    }
                    .frame(width: 66, height: 66)
                    Text(limit.name)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(WTheme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(limit.headline)
                        .font(WTheme.figure(11, weight: .heavy))
                        .foregroundStyle(limit.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    WLabel(text: String(snapshot.year), color: WTheme.ink3)
                    yearStat("\(snapshot.countriesThisYear)", "countries")
                    yearStat("\(snapshot.travelDaysThisYear)", "travel days")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func yearStat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(WTheme.figure(22, weight: .heavy))
                .foregroundStyle(WTheme.auroraGradient)
                .widgetAccentable()
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(WTheme.ink2)
        }
    }

    private func content(snapshot: WidgetSnapshot, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOU'RE IN")
                .font(WTheme.label(8.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(WTheme.aurora1)

            Spacer(minLength: 4)

            Text(flagEmoji(code))
                .font(.system(size: 34))
                .shadow(color: WTheme.aurora1.opacity(0.4), radius: 8)

            Text(widgetCountryName(code))
                .font(WTheme.figure(15, weight: .heavy))
                .foregroundStyle(WTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Text("Day \(max(1, snapshot.dayOfStay))")
                    .font(WTheme.figure(11, weight: .bold))
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
                .font(WTheme.label(8.5, weight: .bold))
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
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
