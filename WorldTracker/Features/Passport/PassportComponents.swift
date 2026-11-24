import SwiftUI
import WorldTrackerKit

/// A country as an ink stamp: dashed border, flag, name, the month it was
/// first entered. Tilt and ink colour are derived from the code, so a given
/// country always looks the same.
struct StampView: View {
    let stamp: PassportStamp
    var isHome = false

    private var seed: Int {
        stamp.code.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
    }

    private var ink: Color {
        if isHome { return Theme.amber }
        return [Theme.aurora1, Theme.aurora2, Theme.aurora1, Theme.amber][abs(seed) % 4]
    }

    private var tilt: Double { Double(abs(seed) % 9) - 4 }

    var body: some View {
        VStack(spacing: 3) {
            Text(flagEmoji(stamp.code))
                .font(.system(size: 30))
            Text(countryName(stamp.code).uppercased())
                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(DayFormat.monthYear(stamp.firstDay).uppercased())
                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink3)
            Text("\(stamp.totalDays)D · \(stamp.visits)×")
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ink.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ink.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
        )
        .rotationEffect(.degrees(tilt))
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(countryName(stamp.code)), first visited \(DayFormat.monthYear(stamp.firstDay)), \(stamp.totalDays) days over \(stamp.visits) visits"
        )
    }
}

/// One continent as a ring with a visited/total count.
struct ContinentRing: View {
    let progress: ContinentProgress

    var body: some View {
        VStack(spacing: 6) {
            RingGauge(
                fraction: progress.fraction,
                lineWidth: 5,
                tint: AnyShapeStyle(progress.visited > 0 ? Theme.aurora1 : Theme.ink3.opacity(0.3))
            ) {
                Text("\(progress.visited)")
                    .font(Theme.numeric(14, weight: .heavy))
                    .foregroundStyle(progress.visited > 0 ? Theme.ink : Theme.ink3)
            }
            .frame(width: 50, height: 50)

            Text(progress.continent.displayName)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(progress.total > 0 ? "of \(progress.total)" : "bonus")
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(progress.continent.displayName): \(progress.visited) of \(progress.total) countries"
        )
    }
}

/// A badge: lit when earned, a progress ring when not.
struct BadgeCell: View {
    let achievement: Achievement

    var body: some View {
        let unlocked = achievement.isUnlocked
        VStack(spacing: 6) {
            ZStack {
                if unlocked {
                    Circle()
                        .fill(Theme.auroraGradient)
                        .shadow(color: Theme.aurora1.opacity(0.35), radius: 8)
                    Image(systemName: achievement.symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.sky)
                } else {
                    RingGauge(
                        fraction: achievement.fraction,
                        lineWidth: 3.5,
                        tint: AnyShapeStyle(Theme.ink3)
                    ) {
                        Image(systemName: achievement.symbol)
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
            .frame(width: 52, height: 52)

            Text(achievement.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(unlocked ? Theme.ink : Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unlocked
                 ? achievement.detail
                 : "\(achievement.current.grouped) / \(achievement.target.grouped)")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.ink3)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 24, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(achievement.title): \(achievement.detail). \(unlocked ? "Earned" : "\(achievement.current) of \(achievement.target)")"
        )
    }
}

/// New countries per year as a small bar chart.
struct YearBars: View {
    let years: [TravelInsights.YearTotals]

    var body: some View {
        let shown = Array(years.suffix(8))
        let top = max(1, shown.map(\.countries).max() ?? 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(shown) { year in
                VStack(spacing: 4) {
                    Text("\(year.countries)")
                        .font(Theme.numeric(10, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.auroraGradient)
                            .opacity(0.3)
                            .frame(height: 64 * CGFloat(year.countries) / CGFloat(top) + 4)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.auroraGradient)
                            .frame(height: 64 * CGFloat(year.newCountries) / CGFloat(top) + (year.newCountries > 0 ? 4 : 0))
                    }
                    .frame(maxWidth: 30)
                    Text(String(year.year).suffix(2))
                        .font(Theme.numeric(9.5, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(year.year): \(year.countries) countries, \(year.newCountries) new")
            }
        }
        .frame(height: 104, alignment: .bottom)
    }
}
