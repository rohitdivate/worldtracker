import SwiftUI
import WorldTrackerKit

/// Shared building blocks introduced with the 2.0 redesign. Everything reads
/// `Theme` tokens, so all three themes get them for free.

/// The small tracked caps label above a section, with an optional action on
/// the right ("Manage", "See all").
struct SectionLabel: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(Theme.label(10.5, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(Theme.ink3)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.aurora1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }
}

/// A circular progress ring. Draws clockwise from 12 o'clock.
struct RingGauge<Center: View>: View {
    let fraction: Double
    var lineWidth: CGFloat = 6
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.auroraGradient)
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline2, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
    }
}

extension RingGauge where Center == EmptyView {
    init(fraction: Double, lineWidth: CGFloat = 6, tint: AnyShapeStyle = AnyShapeStyle(Theme.auroraGradient)) {
        self.init(fraction: fraction, lineWidth: lineWidth, tint: tint) { EmptyView() }
    }
}

/// A slim horizontal progress bar.
struct ProgressBar: View {
    let fraction: Double
    var height: CGFloat = 5
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.auroraGradient)

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Theme.hairline2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, geo.size.width * min(1, max(0, fraction))))
                }
        }
        .frame(height: height)
    }
}

/// A number over a caps caption: the unit Home and Passport are built from.
struct MetricColumn: View {
    let value: String
    let label: String
    var alignment: HorizontalAlignment = .leading
    var valueSize: CGFloat = 20
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.ink)

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(Theme.isBold ? Theme.poster(valueSize * 1.45) : Theme.display(valueSize, weight: .heavy))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(Theme.label(8.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// A rounded icon tile, used as the leading mark of rows and insight cards.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 34
    var tint: Color = Theme.aurora1

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(tint)
            )
    }
}

// MARK: - Day limit styling

extension DayLimitStatus.Level {
    /// One colour per level, so a gauge reads the same on Home, in the
    /// Limits screen and on a widget.
    var color: Color {
        switch self {
        case .clear: Theme.aurora1
        case .watch: Theme.amber
        case .close, .over: Theme.alert
        case .building: Theme.aurora2
        case .reached: Theme.good
        }
    }

    var symbol: String {
        switch self {
        case .clear: "checkmark.circle.fill"
        case .watch: "exclamationmark.circle.fill"
        case .close: "exclamationmark.triangle.fill"
        case .over: "xmark.octagon.fill"
        case .building: "arrow.up.right.circle.fill"
        case .reached: "checkmark.seal.fill"
        }
    }
}

extension DayLimitStatus {
    var tint: AnyShapeStyle { AnyShapeStyle(level.color) }

    /// The sentence under the headline: what happens next.
    var outlook: String {
        func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }
        switch rule.goal {
        case .reachAtLeast:
            if level == .reached { return "Target met for this window" }
            if let reset = daysUntilReset {
                return remaining > reset
                    ? "Out of reach this window: \(days(reset)) left in it"
                    : "\(days(reset)) left in this window"
            }
            return "Keep counting"
        case .stayUnder:
            if level == .over || used == rule.limit {
                if let relief = reliefDay {
                    return "Days free up from \(DayFormat.long(relief))"
                }
                if let reset = daysUntilReset {
                    return "Resets in \(days(reset))"
                }
                return "No days left"
            }
            if isSafeUntilReset, let reset = daysUntilReset {
                return "Can't be exceeded before it resets in \(days(reset))"
            }
            if let runway = runwayDays {
                let end = asOf + runway
                return countsToday
                    ? "Stay through \(DayFormat.long(end)) at most"
                    : "Up to \(days(runway)) if you went tomorrow"
            }
            return "No ceiling in reach"
        }
    }
}

extension DayFormat {
    /// "14 Mar 2026": an unambiguous date for deadlines.
    static func long(_ epochDay: Int) -> String {
        let c = EpochDay(value: epochDay).civil()
        let months = DateFormatter().shortMonthSymbols ?? []
        let month = (1...months.count).contains(c.month) ? months[c.month - 1] : "?"
        return "\(c.day) \(month) \(c.year)"
    }

    /// "Mar 2026"
    static func monthYear(_ epochDay: Int) -> String {
        let c = EpochDay(value: epochDay).civil()
        let months = DateFormatter().shortMonthSymbols ?? []
        let month = (1...months.count).contains(c.month) ? months[c.month - 1] : "?"
        return "\(month) \(c.year)"
    }
}

extension Int {
    /// 12,450: grouped for distances and big day counts.
    var grouped: String {
        formatted(.number.grouping(.automatic))
    }
}
