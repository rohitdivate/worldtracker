import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Countries" (small) — this year's tally with the flags you collected.
struct CountriesWidgetView: View {
    var entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.countriesThisYear > 0 {
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
        VStack(alignment: .leading, spacing: 0) {
            Text("COUNTRIES · \(String(snapshot.year))")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(WTheme.aurora1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            Text("\(snapshot.countriesThisYear)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.auroraGradient)

            Spacer(minLength: 2)

            flagRow(snapshot)

            Text("\(snapshot.travelDaysThisYear) travel days")
                .font(.system(size: 10))
                .foregroundStyle(WTheme.ink2)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func flagRow(_ snapshot: WidgetSnapshot) -> some View {
        let codes = snapshot.countries.prefix(6).map(\.code)
        return HStack(spacing: 2) {
            ForEach(codes, id: \.self) { code in
                Text(flagEmoji(code)).font(.system(size: 13))
            }
            if snapshot.countries.count > 6 {
                Text("+\(snapshot.countries.count - 6)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.ink3)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COUNTRIES")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(WTheme.aurora1)
            Spacer()
            Text("0")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.ink3)
            Text("The year is young")
                .font(.system(size: 10))
                .foregroundStyle(WTheme.ink2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct CountriesWidget: Widget {
    let kind = "CountriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            CountriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Countries")
        .description("How many countries this year, and their flags.")
        .supportedFamilies([.systemSmall])
    }
}
