import AppIntents
import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Day Limit" — how much of a ceiling is used and what is left. Small and
/// medium for the Home Screen and StandBy; circular, rectangular and inline
/// for the Lock Screen. Configurable: pick a rule, or let it follow the
/// most pressing one.

struct LimitEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let limitID: String?
}

struct LimitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LimitEntry {
        LimitEntry(date: Date(), snapshot: .sample, limitID: nil)
    }

    func snapshot(for configuration: SelectLimitIntent, in context: Context) async -> LimitEntry {
        let snapshot = context.isPreview ? .sample : (WidgetSnapshotReader.load() ?? .sample)
        return LimitEntry(date: Date(), snapshot: snapshot, limitID: configuration.limit?.id)
    }

    func timeline(for configuration: SelectLimitIntent, in context: Context) async -> Timeline<LimitEntry> {
        let entry = LimitEntry(
            date: Date(), snapshot: WidgetSnapshotReader.load(), limitID: configuration.limit?.id
        )
        // Counts roll at midnight; the app pushes reloads for everything else.
        let nextMidnight = Calendar.current
            .startOfDay(for: Date())
            .addingTimeInterval(24 * 60 * 60 + 60)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

struct DayLimitWidgetView: View {
    var entry: LimitEntry

    @Environment(\.widgetFamily) private var family

    private var status: WidgetSnapshot.LimitStatus? {
        entry.snapshot?.pressingLimit(preferring: entry.limitID)
    }

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) {
            if isAccessory {
                AccessoryWidgetBackground()
            } else {
                WTheme.background
            }
        }
        .widgetURL(URL(string: status.map { "beenthere://limits/\($0.id)" } ?? "beenthere://limits"))
    }

    // MARK: - Home Screen

    @ViewBuilder
    private var small: some View {
        if let status {
            VStack(alignment: .leading, spacing: 0) {
                WLabel(text: status.name)
                Spacer(minLength: 4)
                HStack {
                    Spacer(minLength: 0)
                    ring(status, size: 74, lineWidth: 8)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 4)
                Text(status.headline)
                    .font(WTheme.figure(14, weight: .heavy))
                    .foregroundStyle(status.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            empty
        }
    }

    @ViewBuilder
    private var medium: some View {
        if let status {
            let others = (entry.snapshot?.limits ?? []).filter { $0.id != status.id }.prefix(2)
            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    ring(status, size: 84, lineWidth: 9)
                    Text(status.headline)
                        .font(WTheme.figure(12.5, weight: .heavy))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .widgetAccentable()
                }
                .frame(width: 104)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        WLabel(text: "Day limits")
                        Spacer()
                        WTheme.Wordmark()
                    }
                    Spacer(minLength: 6)
                    row(status, emphasised: true)
                    ForEach(Array(others), id: \.id) { other in
                        Spacer(minLength: 6)
                        row(other, emphasised: false)
                    }
                    Spacer(minLength: 6)
                    Text(status.detail)
                        .font(.system(size: 9))
                        .foregroundStyle(WTheme.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            empty
        }
    }

    private func ring(_ status: WidgetSnapshot.LimitStatus, size: CGFloat, lineWidth: CGFloat) -> some View {
        WRing(fraction: status.fraction, lineWidth: lineWidth, tint: status.color) {
            VStack(spacing: -2) {
                Text("\(status.used)")
                    .font(WTheme.figure(size * 0.33, weight: .heavy))
                    .foregroundStyle(WTheme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("of \(status.limit)")
                    .font(.system(size: size * 0.125, weight: .semibold))
                    .foregroundStyle(WTheme.ink3)
            }
            .padding(lineWidth + 3)
        }
        .frame(width: size, height: size)
    }

    private func row(_ status: WidgetSnapshot.LimitStatus, emphasised: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(status.name)
                    .font(.system(size: 11.5, weight: emphasised ? .bold : .semibold))
                    .foregroundStyle(emphasised ? WTheme.ink : WTheme.ink2)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(status.used)/\(status.limit)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(status.color)
            }
            WBar(fraction: status.fraction, height: 3.5, tint: status.color)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 5) {
            WLabel(text: "Day limit")
            Spacer()
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 24))
                .foregroundStyle(WTheme.aurora1)
            Text(entry.snapshot == nil
                 ? widgetEmptyMessage
                 : "Add a day limit in Been There to count it here")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Lock Screen (system-tinted, so no custom colours)

    @ViewBuilder
    private var circular: some View {
        if let status {
            Gauge(value: Double(status.used), in: 0...Double(max(1, status.limit))) {
                Image(systemName: "calendar")
            } currentValueLabel: {
                Text("\(status.remaining)")
                    .font(WTheme.figure(16, weight: .heavy))
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 22))
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let status {
            VStack(alignment: .leading, spacing: 2) {
                Text(status.name)
                    .font(WTheme.figure(13, weight: .heavy))
                    .lineLimit(1)
                    .widgetAccentable()
                Text("\(status.headline) · \(status.used)/\(status.limit)")
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                Gauge(value: Double(status.used), in: 0...Double(max(1, status.limit))) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text("Day limit")
                    .font(WTheme.figure(13, weight: .heavy))
                Text("Add one in Been There")
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let status {
            Label("\(status.name): \(status.headline)", systemImage: "calendar.badge.clock")
        } else {
            Label("No day limit set", systemImage: "calendar.badge.clock")
        }
    }
}

struct DayLimitWidget: Widget {
    let kind = "DayLimitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLimitIntent.self, provider: LimitProvider()) { entry in
            DayLimitWidgetView(entry: entry)
        }
        .configurationDisplayName("Day Limit")
        .description("Days used and days left on a limit like Schengen 90/180.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
