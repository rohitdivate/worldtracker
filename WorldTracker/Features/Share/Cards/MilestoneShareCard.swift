import SwiftUI
import WorldTrackerKit

/// A lifetime milestone as a card — the big number, what it means, and the
/// flags that earned it.
struct MilestoneShareCard: View {
    let milestone: Milestone
    let flags: [String]
    let dateText: String

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 8) {
                Spacer()

                Text(bigValue)
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.auroraGradient)
                    .shadow(color: Theme.aurora1.opacity(0.4), radius: 20)

                Text(headline)
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.amber)

                if !flags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(flags.prefix(9), id: \.self) { code in
                            Text(flagEmoji(code)).font(.system(size: 21))
                        }
                    }
                    .padding(.top, 12)
                }

                Text(dateText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 8)

                Spacer()

                ShareWordmark(withHook: true)
                    .padding(.bottom, 26)
            }
        }
        .frame(width: 360, height: 450)
    }

    private var bigValue: String {
        switch milestone {
        case .countryCount(let n): return "\(n)"
        case .travelDays(let n): return "\(n)"
        case .worldPercent(let p): return "\(p)%"
        case .longestTripBeaten(let days, _): return "\(days)"
        }
    }

    private var headline: String {
        switch milestone {
        case .countryCount: return "COUNTRIES"
        case .travelDays: return "TRAVEL DAYS"
        case .worldPercent: return "OF THE WORLD"
        case .longestTripBeaten: return "DAYS — LONGEST TRIP YET"
        }
    }
}

#Preview {
    MilestoneShareCard(
        milestone: .countryCount(10),
        flags: ["GB", "ES", "JP", "DK", "FR"],
        dateText: "18 July 2026"
    )
}
