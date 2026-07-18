import SwiftUI
import WorldTrackerKit

/// History as a list of stays: every entry/exit segment, newest first —
/// Bounded's List view, with border days shared between neighboring rows.
struct TripListView: View {
    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let _ = store.changeToken
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let segments = store.segments(in: earliest...today)
        let (todayYear, _, _) = EpochDay(value: today).civil()

        ScrollView {
            LazyVStack(spacing: 8) {
                if segments.isEmpty {
                    Text("No trips yet — they'll appear as tracking and photo history fill in.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 60)
                }

                ForEach(segments) { segment in
                    NavigationLink(value: segment.countryCode) {
                        HStack(spacing: 12) {
                            FlagChip(code: segment.countryCode, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(countryName(segment.countryCode))
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    if segment.countryCode == store.homeCountry {
                                        Text("HOME")
                                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(Theme.amber)
                                    }
                                }
                                Text(DayFormat.shortRange(segment.startDay, segment.endDay, todayYear: todayYear))
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.ink3)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(segment.endDay >= today ? "NOW" : "\(segment.dayCount)")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(segment.endDay >= today ? Theme.amber : Theme.aurora1)
                                if segment.endDay < today {
                                    Text(segment.dayCount == 1 ? "DAY" : "DAYS")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(Theme.ink3)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.ink3)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .nightCard()
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

#Preview {
    NavigationStack { TripListView() }
        .preferredColorScheme(.dark)
}
