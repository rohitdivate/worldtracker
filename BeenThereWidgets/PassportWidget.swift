import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Passport" — the stamp collection. Medium shows the three newest stamps
/// beside the lifetime count; large is a full page of nine with continents
/// along the bottom.
struct PassportWidgetView: View {
    var entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let stamps = snapshot.stamps, !stamps.isEmpty {
                if family == .systemLarge {
                    large(snapshot, stamps: stamps)
                } else {
                    medium(snapshot, stamps: stamps)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://passport"))
    }

    private func count(_ snapshot: WidgetSnapshot) -> Int {
        snapshot.allTimeCountries ?? snapshot.stamps?.count ?? 0
    }

    private func worldShare(_ snapshot: WidgetSnapshot) -> Int {
        Int((Double(count(snapshot)) / 195.0 * 100).rounded())
    }

    private func medium(_ snapshot: WidgetSnapshot, stamps: [WidgetSnapshot.Stamp]) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                WLabel(text: "Passport")
                Spacer(minLength: 2)
                Text("\(count(snapshot))")
                    .font(WTheme.poster(44, weight: .heavy))
                    .foregroundStyle(WTheme.auroraGradient)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .widgetAccentable()
                Text("countries · \(worldShare(snapshot))% of the world")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WTheme.ink2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if let unlocked = snapshot.badgesUnlocked, let total = snapshot.badgesTotal {
                    Text("\(unlocked)/\(total) badges")
                        .font(WTheme.figure(9.5, weight: .bold))
                        .foregroundStyle(WTheme.amber)
                }
            }
            .frame(width: 112, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(Array(stamps.prefix(3)), id: \.code) { stamp in
                    WStampTile(stamp: stamp, isHome: stamp.code == snapshot.homeCountry)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func large(_ snapshot: WidgetSnapshot, stamps: [WidgetSnapshot.Stamp]) -> some View {
        let page = Array(stamps.prefix(9))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                WLabel(text: "Passport")
                Spacer()
                Text("\(count(snapshot)) countries · \(worldShare(snapshot))%")
                    .font(WTheme.figure(10, weight: .bold))
                    .foregroundStyle(WTheme.amber)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(page, id: \.code) { stamp in
                    WStampTile(stamp: stamp, isHome: stamp.code == snapshot.homeCountry)
                        .frame(height: 66)
                }
            }
            .frame(maxHeight: .infinity)

            if let continents = snapshot.continents {
                HStack(spacing: 0) {
                    ForEach(continents.filter { $0.total > 0 }, id: \.key) { continent in
                        VStack(spacing: 2) {
                            Text("\(continent.visited)")
                                .font(WTheme.figure(13, weight: .heavy))
                                .foregroundStyle(continent.visited > 0 ? WTheme.aurora1 : WTheme.ink3)
                            Text(shortName(continent.key))
                                .font(WTheme.label(7, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(WTheme.ink3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shortName(_ key: String) -> String {
        Continent(rawValue: key)?.shortName ?? key.uppercased()
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 26))
                .foregroundStyle(WTheme.aurora1)
            Text(entry.snapshot == nil
                 ? widgetEmptyMessage
                 : "Your first stamp appears after your first tracked day")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PassportWidget: Widget {
    let kind = "PassportWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            PassportWidgetView(entry: entry)
        }
        .configurationDisplayName("Passport")
        .description("Your newest stamps and how much of the world you've seen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// "Continents" — a ring per continent.
struct ContinentsWidgetView: View {
    var entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let continents = entry.snapshot?.continents, !continents.isEmpty {
                content(continents)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://passport"))
    }

    private func content(_ continents: [WidgetSnapshot.ContinentCount]) -> some View {
        let visited = continents.filter { $0.visited > 0 }.count
        let isMedium = family == .systemMedium
        let ringSize: CGFloat = isMedium ? 34 : 30

        return VStack(alignment: .leading, spacing: isMedium ? 8 : 5) {
            HStack(alignment: .firstTextBaseline) {
                WLabel(text: "Continents")
                Spacer()
                Text("\(visited) of 7")
                    .font(WTheme.figure(11, weight: .heavy))
                    .foregroundStyle(WTheme.amber)
            }

            if isMedium {
                HStack(spacing: 0) {
                    ForEach(continents, id: \.key) { continent in
                        cell(continent, size: ringSize, showsTotal: true)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                // 4 + 3, so seven rings sit in a square without crowding.
                VStack(spacing: 5) {
                    HStack(spacing: 0) {
                        ForEach(continents.prefix(4), id: \.key) { continent in
                            cell(continent, size: ringSize, showsTotal: false)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    HStack(spacing: 0) {
                        ForEach(continents.dropFirst(4), id: \.key) { continent in
                            cell(continent, size: ringSize, showsTotal: false)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(
        _ continent: WidgetSnapshot.ContinentCount, size: CGFloat, showsTotal: Bool
    ) -> some View {
        let fraction = continent.total > 0
            ? min(1, Double(continent.visited) / Double(continent.total))
            : (continent.visited > 0 ? 1 : 0)
        return VStack(spacing: 3) {
            WRing(
                fraction: fraction,
                lineWidth: 3.5,
                tint: continent.visited > 0 ? WTheme.aurora1 : WTheme.ink3.opacity(0.3)
            ) {
                Text("\(continent.visited)")
                    .font(WTheme.figure(size * 0.36, weight: .heavy))
                    .foregroundStyle(continent.visited > 0 ? WTheme.ink : WTheme.ink3)
            }
            .frame(width: size, height: size)
            Text(Continent(rawValue: continent.key)?.shortName ?? "")
                .font(WTheme.label(7, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(WTheme.ink3)
            if showsTotal {
                Text(continent.total > 0 ? "of \(continent.total)" : "bonus")
                    .font(.system(size: 7))
                    .foregroundStyle(WTheme.ink3)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 5) {
            WLabel(text: "Continents")
            Spacer()
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 24))
                .foregroundStyle(WTheme.aurora1)
            Text(widgetEmptyMessage)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ContinentsWidget: Widget {
    let kind = "ContinentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ContinentsWidgetView(entry: entry)
        }
        .configurationDisplayName("Continents")
        .description("A ring for each continent, filling as you go.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
