import SwiftUI
import WorldTrackerKit

/// History as a list of stays: every entry/exit segment, newest first —
/// Bounded's List view, with border days shared between neighboring rows.
struct TripListView: View {
    @State private var showHomeStays = false

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let _ = store.changeToken
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let timeline = store.homeTimeline
        let segments = showHomeStays
            ? store.segments(in: earliest...today)
            : store.tripSegments(in: earliest...today)
        let (todayYear, _, _) = EpochDay(value: today).civil()

        ScrollView {
            LazyVStack(spacing: 8) {
                if !timeline.isEmpty {
                    homeStaysChip
                }

                if segments.isEmpty {
                    Text(showHomeStays
                         ? "No stays yet — they'll appear as tracking and photo history fill in."
                         : "No trips yet — time at home doesn't count as a trip.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 60)
                }

                ForEach(segments) { segment in
                    NavigationLink(value: segment) {
                        HStack(spacing: 12) {
                            FlagChip(code: segment.countryCode, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(countryName(segment.countryCode))
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    if showHomeStays,
                                       DayLedgerResolver.isHomeStay(segment, timeline: timeline) {
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

    private var homeStaysChip: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.3)) { showHomeStays.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showHomeStays ? "house.fill" : "house")
                        .font(.system(size: 10, weight: .semibold))
                    Text(showHomeStays ? "Showing home stays" : "Show home stays")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(showHomeStays ? Theme.amber : Theme.ink3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Theme.card)
                        .overlay(Capsule().strokeBorder(
                            showHomeStays ? Theme.amber.opacity(0.4) : Theme.hairline, lineWidth: 1
                        ))
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack { TripListView() }
        .preferredColorScheme(.dark)
}
