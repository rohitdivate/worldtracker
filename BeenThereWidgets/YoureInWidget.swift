import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "You're In" — the flag under your feet, day of stay, days this year.
/// The approved small-widget design from the Night Flight widget deck.

struct YoureInEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct YoureInProvider: TimelineProvider {
    func placeholder(in context: Context) -> YoureInEntry {
        YoureInEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (YoureInEntry) -> Void) {
        let snapshot = context.isPreview
            ? .sample
            : (WidgetSnapshotReader.load() ?? .sample)
        completion(YoureInEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<YoureInEntry>) -> Void) {
        let entry = YoureInEntry(date: Date(), snapshot: WidgetSnapshotReader.load())
        // Day counters change at midnight; the app pushes reloads for the rest.
        let nextMidnight = Calendar.current
            .startOfDay(for: Date())
            .addingTimeInterval(24 * 60 * 60 + 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct YoureInWidgetView: View {
    var entry: YoureInEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let code = snapshot.currentCountry {
                content(snapshot: snapshot, code: code)
            } else {
                waiting
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
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
            Text("Open the app once to light this up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct YoureInWidget: Widget {
    let kind = "YoureInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YoureInProvider()) { entry in
            YoureInWidgetView(entry: entry)
        }
        .configurationDisplayName("You're In")
        .description("The country under your feet, at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
