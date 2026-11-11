import SwiftUI
import WidgetKit
import WorldTrackerKit

/// Pieces shared by the 2.0 widgets. Mirrors the app's `Components.swift`
/// in spirit; the two targets can't share SwiftUI source, only Kit data.

/// Circular progress ring, clockwise from 12 o'clock.
struct WRing<Center: View>: View {
    let fraction: Double
    var lineWidth: CGFloat = 6
    var tint: Color = WTheme.aurora1
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(WTheme.hairline2, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            center()
        }
    }
}

struct WBar: View {
    let fraction: Double
    var height: CGFloat = 4
    var tint: Color = WTheme.aurora1

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(WTheme.hairline2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, geo.size.width * min(1, max(0, fraction))))
                        .widgetAccentable()
                }
        }
        .frame(height: height)
    }
}

/// The small tracked caps label every widget opens with.
struct WLabel: View {
    let text: String
    var color: Color = WTheme.aurora1

    var body: some View {
        Text(text.uppercased())
            .font(WTheme.label(8.5, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .widgetAccentable()
    }
}

extension WidgetSnapshot.LimitStatus {
    var fraction: Double {
        limit > 0 ? min(1, max(0, Double(used) / Double(limit))) : 1
    }

    var remaining: Int { max(0, limit - used) }

    /// Same colour-per-level mapping as the app.
    var color: Color { WLevel.color(level) }
}

enum WLevel {
    static func color(_ raw: String?) -> Color {
        switch raw {
        case "watch": WTheme.amber
        case "close", "over": WTheme.alert
        case "building": WTheme.aurora2
        case "reached": WTheme.good
        default: WTheme.aurora1
        }
    }
}

extension WidgetSnapshot {
    /// The limit a glance should show when the user hasn't picked one: a
    /// ceiling that is counting today, else the fullest ceiling, else
    /// whatever comes first.
    func pressingLimit(preferring id: String? = nil) -> LimitStatus? {
        let all = limits ?? []
        if let id, let chosen = all.first(where: { $0.id == id }) { return chosen }
        let ceilings = all.filter(\.isCeiling)
        return ceilings.filter(\.countsToday).max { $0.fraction < $1.fraction }
            ?? ceilings.max { $0.fraction < $1.fraction }
            ?? all.first
    }

    /// Tone per day of the year so far, from `dayTones` when the app wrote
    /// it, else rebuilt from the older home/away flags.
    var tones: [DayTone] {
        if let dayTones {
            return dayTones.map { character in
                switch character {
                case "h": .home
                case "a": .away
                case "c": .crossing
                default: .unknown
                }
            }
        }
        return (travelDayFlags ?? []).map { $0 ? .away : .home }
    }
}

enum WTone {
    static func color(_ tone: DayTone) -> Color {
        switch tone {
        case .home: WTheme.ink3.opacity(0.42)
        case .away: WTheme.aurora1
        case .crossing: WTheme.aurora2
        case .unknown: WTheme.ink3.opacity(0.16)
        case .future: WTheme.ink3.opacity(0.08)
        }
    }
}

func widgetMonthYear(_ epochDay: Int) -> String {
    let c = EpochDay(value: epochDay).civil()
    let months = DateFormatter().shortMonthSymbols ?? []
    let month = (1...months.count).contains(c.month) ? months[c.month - 1] : "?"
    return "\(month) \(String(c.year).suffix(2))"
}

/// A passport stamp, small enough for a widget cell.
struct WStampTile: View {
    let stamp: WidgetSnapshot.Stamp
    var isHome = false
    var compact = false

    private var seed: Int {
        stamp.code.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
    }

    private var ink: Color {
        if isHome { return WTheme.amber }
        return [WTheme.aurora1, WTheme.aurora2, WTheme.aurora1, WTheme.amber][abs(seed) % 4]
    }

    var body: some View {
        VStack(spacing: compact ? 1 : 2) {
            Text(flagEmoji(stamp.code))
                .font(.system(size: compact ? 17 : 22))
            Text(stamp.code)
                .font(.system(size: compact ? 7.5 : 8.5, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(ink)
                .widgetAccentable()
            if !compact {
                Text(widgetMonthYear(stamp.firstDay).uppercased())
                    .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WTheme.ink3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(ink.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(ink.opacity(0.65), style: StrokeStyle(lineWidth: 1.1, dash: [4, 2.5]))
        )
        .rotationEffect(.degrees(Double(abs(seed) % 7) - 3))
    }
}
