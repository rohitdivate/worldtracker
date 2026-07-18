import SwiftUI
import WorldTrackerKit

/// Home: the living aurora header that answers "where am I, how long have I
/// been here" before you ask.
struct HomeView: View {
    @Environment(LocationService.self) private var location

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let _ = store.changeToken  // re-render when the ledger changes
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    todayCard
                        .padding(.top, 16)

                    quickStats

                    if store.currentStay() == nil {
                        waitingCard
                    }

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var todayCard: some View {
        let stay = store.currentStay()
        let code = stay?.countryCode

        return VStack(alignment: .leading, spacing: 14) {
            Text("YOU'RE IN")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Theme.aurora1)

            HStack(spacing: 14) {
                if let code {
                    FlagChip(code: code, size: 56)
                        .shadow(color: Theme.aurora1.opacity(0.35), radius: 14)
                } else {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 56, height: 56)
                        .overlay(Text("🌍").font(.system(size: 30)))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(code.map(countryName) ?? "Finding you…")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    if let stay {
                        Text("Day \(stay.days) of this stay · \(store.daysThisYear(in: stay.countryCode)) days here this year")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink2)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    private var quickStats: some View {
        let today = store.todayEpoch
        let (year, _, _) = EpochDay(value: today).civil()
        let jan1 = EpochDay.daysFromCivil(year: year, month: 1, day: 1)
        let stats = store.stats(in: jan1...today)

        return HStack(spacing: 10) {
            statTile(value: stats.countriesVisited, label: "Countries")
            statTile(value: stats.borderCrossings, label: "Crossings")
            statTile(value: stats.travelDays, label: "Travel days")
        }
    }

    private func statTile(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.auroraGradient)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .nightCard()
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Waiting for your first location")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            } icon: {
                Image(systemName: "location.viewfinder")
                    .foregroundStyle(Theme.aurora1)
                    .symbolEffect(.pulse)
            }
            Text("Keep the app installed and carry on with your day — the first significant-location event arrives on its own. Or open Settings → Tracking health to check permissions.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
