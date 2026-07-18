import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "On This Day" — where you were on this date, years ago, with the photo
/// you took there. The Day One / Photos memories pattern.
struct OnThisDayWidgetView: View {
    var entry: SnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var memories: [WidgetSnapshot.OnThisDayEntry] {
        entry.snapshot?.onThisDay ?? []
    }

    /// The hero memory: prefers one with a photo, then the most recent year.
    private var hero: WidgetSnapshot.OnThisDayEntry? {
        memories.first(where: \.hasPhoto) ?? memories.first
    }

    var body: some View {
        Group {
            if let hero {
                content(hero)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            if hero?.hasPhoto == true, let image = WidgetSnapshotReader.onThisDayImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.05), .black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                WTheme.background
            }
        }
        .widgetURL(URL(string: "beenthere://calendar"))
    }

    private func content(_ memory: WidgetSnapshot.OnThisDayEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ON THIS DAY · \(memory.yearsAgo) \(memory.yearsAgo == 1 ? "YEAR" : "YEARS") AGO")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(WTheme.aurora1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            if let code = memory.countryCode {
                Text(flagEmoji(code))
                    .font(.system(size: family == .systemMedium ? 26 : 22))
                    .shadow(color: .black.opacity(0.4), radius: 3)
            }
            Text(placeLine(memory))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if family == .systemMedium, memories.count > 1 {
                otherYears
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func placeLine(_ memory: WidgetSnapshot.OnThisDayEntry) -> String {
        let country = memory.countryCode.map(widgetCountryName)
        return [memory.city, country].compactMap { $0 }.joined(separator: ", ")
    }

    /// The other anniversaries, as a compact flag row.
    private var otherYears: some View {
        HStack(spacing: 8) {
            ForEach(memories.dropFirst().prefix(4), id: \.yearsAgo) { memory in
                HStack(spacing: 3) {
                    if let code = memory.countryCode {
                        Text(flagEmoji(code)).font(.system(size: 12))
                    }
                    Text("\(memory.yearsAgo)y")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.35), in: Capsule())
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ON THIS DAY")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(WTheme.aurora1)
            Spacer()
            Text("🗓️").font(.system(size: 26))
            Text(entry.snapshot == nil
                 ? widgetEmptyMessage
                 : "Your travel anniversaries appear here as your history grows")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct OnThisDayWidget: Widget {
    let kind = "OnThisDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            OnThisDayWidgetView(entry: entry)
        }
        .configurationDisplayName("On This Day")
        .description("Where you were on this date, years ago — photo included.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
