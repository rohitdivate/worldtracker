import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Your Top" (medium) — the ranked countries of the year with aurora bars.
struct YourTopWidgetView: View {
    var entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, !snapshot.countries.isEmpty {
                content(snapshot)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://home"))
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let top = Array(snapshot.countries.prefix(3))
        let maxDays = top.first?.days ?? 1

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("YOUR TOP · \(String(snapshot.year))")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(WTheme.aurora1)
                Spacer()
                Text("\(snapshot.countriesThisYear) countries")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WTheme.ink3)
            }

            ForEach(Array(top.enumerated()), id: \.element.code) { index, entry in
                HStack(spacing: 8) {
                    Text(flagEmoji(entry.code))
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(widgetCountryName(entry.code))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WTheme.ink)
                                .lineLimit(1)
                            if entry.code == snapshot.homeCountry {
                                Text("HOME")
                                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(WTheme.amber)
                            }
                            Spacer()
                            Text("\(entry.days)d")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(index == 0 ? WTheme.amber : WTheme.aurora1)
                        }
                        GeometryReader { geo in
                            Capsule()
                                .fill(WTheme.ink3.opacity(0.25))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(WTheme.auroraGradient)
                                        .frame(width: max(4, geo.size.width * CGFloat(entry.days) / CGFloat(maxDays)))
                                }
                        }
                        .frame(height: 3)
                    }
                }
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
        .description("Where your year lived — ranked, with day counts.")
        .supportedFamilies([.systemMedium])
    }
}
