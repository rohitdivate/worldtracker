import AppIntents
import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Your Top" — the ranked countries with aurora bars. Interactive: the pill
/// in the corner flips between this year and all time without opening the
/// app. Medium shows three rows, large seven.
struct YourTopWidgetView: View {
    var entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var period: TopPeriod {
        // No lifetime list in an older snapshot: stay on the year.
        entry.snapshot?.allTimeTop == nil ? .year : TopPeriod.current
    }

    private func ranking(_ snapshot: WidgetSnapshot) -> [WidgetSnapshot.CountryDays] {
        period == .allTime ? (snapshot.allTimeTop ?? snapshot.countries) : snapshot.countries
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, !ranking(snapshot).isEmpty {
                content(snapshot)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://countries"))
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let rows = family == .systemLarge ? 7 : 3
        let top = Array(ranking(snapshot).prefix(rows))
        let maxDays = top.first?.days ?? 1
        let total = period == .allTime
            ? (snapshot.allTimeCountries ?? top.count)
            : snapshot.countriesThisYear

        return VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 7) {
            HStack {
                WLabel(text: "Your top")
                Text("\(total) countries")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WTheme.ink3)
                Spacer()
                Button(intent: ToggleTopPeriodIntent()) {
                    HStack(spacing: 3) {
                        Text(period == .allTime ? "All time" : String(snapshot.year))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .font(WTheme.figure(9.5, weight: .bold))
                    .foregroundStyle(WTheme.sky)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(WTheme.auroraGradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(top.enumerated()), id: \.element.code) { index, row in
                HStack(spacing: 8) {
                    Text(flagEmoji(row.code))
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(widgetCountryName(row.code))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WTheme.ink)
                                .lineLimit(1)
                            if row.code == snapshot.homeCountry {
                                Text("HOME")
                                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(WTheme.amber)
                            }
                            Spacer()
                            Text("\(row.days)d")
                                .font(WTheme.figure(11, weight: .bold))
                                .foregroundStyle(index == 0 ? WTheme.amber : WTheme.aurora1)
                        }
                        WBar(
                            fraction: Double(row.days) / Double(max(1, maxDays)),
                            height: 3,
                            tint: WTheme.aurora1
                        )
                    }
                }
            }
            if family == .systemLarge {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("🌍").font(.system(size: 28))
            Text(entry.snapshot == nil
                 ? widgetEmptyMessage
                 : "Your top countries appear here after your first tracked days")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct YourTopWidget: Widget {
    let kind = "YourTopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            YourTopWidgetView(entry: entry)
        }
        .configurationDisplayName("Your Top")
        .description("Where your days went, ranked. Tap the pill to switch between this year and all time.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
