import SwiftUI
import WidgetKit
import WorldTrackerKit

/// "Travel Graph" — the year as a contribution-style dot grid: every travel
/// day lit in aurora, in true calendar positions.
struct TravelGraphWidgetView: View {
    var entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let flags = snapshot.travelDayFlags {
                content(snapshot: snapshot, flags: flags)
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            WTheme.background
        }
        .widgetURL(URL(string: "beenthere://calendar"))
    }

    private func content(snapshot: WidgetSnapshot, flags: [Bool]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("TRAVEL GRAPH · \(String(snapshot.year))")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(WTheme.aurora1)
                Spacer()
                Text("\(snapshot.travelDaysThisYear) travel days")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.amber)
            }

            dotGrid(flags: flags)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dotGrid(flags: [Bool]) -> some View {
        Canvas { context, size in
            guard !flags.isEmpty else { return }
            // Full-year grid so the shape reads as "the year", even mid-year.
            let total = max(flags.count, 365)
            let columns = 27
            let rows = Int((Double(total) / Double(columns)).rounded(.up))
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let dot = cell * 0.58
            let xInset = (size.width - cell * CGFloat(columns)) / 2

            for index in 0..<total {
                let col = index % columns
                let row = index / columns
                let rect = CGRect(
                    x: xInset + CGFloat(col) * cell + (cell - dot) / 2,
                    y: CGFloat(row) * cell + (cell - dot) / 2,
                    width: dot,
                    height: dot
                )
                let color: Color
                if index < flags.count {
                    color = flags[index] ? WTheme.aurora1 : WTheme.ink3.opacity(0.35)
                } else {
                    color = WTheme.ink3.opacity(0.15)   // the future, faint
                }
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("📊").font(.system(size: 26))
            Text(widgetEmptyMessage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WTheme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TravelGraphWidget: Widget {
    let kind = "TravelGraphWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            TravelGraphWidgetView(entry: entry)
        }
        .configurationDisplayName("Travel Graph")
        .description("Your year as a dot grid — every travel day lit.")
        .supportedFamilies([.systemMedium])
    }
}
