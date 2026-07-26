import SwiftUI
import WorldTrackerKit

func countryName(_ code: String) -> String {
    Locale.current.localizedString(forRegionCode: code) ?? code
}

/// Circular flag chip — the app's atom.
struct FlagChip: View {
    let code: String
    var size: CGFloat = 32

    var body: some View {
        Circle()
            .fill(Theme.card)
            .frame(width: size, height: size)
            .overlay(
                Text(flagEmoji(code))
                    .font(.system(size: size * 0.58))
            )
            .overlay(
                Circle().strokeBorder(Theme.hairline2, lineWidth: 1)
            )
    }
}

/// Border-crossing day: two half flags in one chip.
struct SplitFlagChip: View {
    let first: String
    let second: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(Theme.card)
            Text(flagEmoji(first))
                .font(.system(size: size * 0.58))
                .mask(alignment: .leading) {
                    Rectangle().frame(width: size / 2)
                }
            Text(flagEmoji(second))
                .font(.system(size: size * 0.58))
                .mask(alignment: .trailing) {
                    Rectangle().frame(width: size / 2)
                }
            Rectangle()
                // Themed, not white: on a light ground a white divider between
                // the two half-flags is invisible.
                .fill(Theme.gloss)
                .frame(width: 1, height: size * 0.7)
                .rotationEffect(.degrees(12))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Theme.aurora1.opacity(0.45), lineWidth: 1)
        )
    }
}

/// Provenance chip in the Passport style — the "stamped" evidence label.
struct ProvenanceStamp: View {
    let source: FactSource

    private var config: (label: String, color: Color) {
        switch source {
        case .gps: return ("GPS", Theme.aurora1)
        case .visit: return ("VISIT", Theme.aurora1)
        case .photo: return ("PHOTOS", Theme.aurora2)
        case .manual: return ("MANUAL", Theme.amber)
        case .timezoneHint: return ("TIMEZONE", Theme.ink3)
        case .importedTimeline: return ("TIMELINE", Theme.aurora2)
        case .importedFlight: return ("FLIGHT", Theme.aurora2)
        }
    }

    var body: some View {
        Text(config.label)
            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
            .tracking(0.8)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .foregroundStyle(config.color)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(config.color.opacity(0.55), lineWidth: 1.2)
            )
            .rotationEffect(.degrees(-1.5))
    }
}

#Preview {
    HStack(spacing: 14) {
        FlagChip(code: "GB")
        SplitFlagChip(first: "GB", second: "ES")
        VStack(spacing: 6) {
            ProvenanceStamp(source: .gps)
            ProvenanceStamp(source: .photo)
            ProvenanceStamp(source: .manual)
        }
    }
    .padding(40)
    .background(Theme.sky)
}
