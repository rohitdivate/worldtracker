import SwiftUI
import WorldTrackerKit

/// The days the ledger has no direct evidence for, as runs that can each be
/// settled in one tap. `range` nil = the whole history.
struct GapReviewView: View {
    let range: ClosedRange<Int>?

    @State private var kind: DayRun.Kind = .unknown
    @State private var picking: DayRun?
    @State private var confirmAll = false

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var edit: EditService { AppContainer.shared.editService }

    private var scope: ClosedRange<Int> {
        let today = store.todayEpoch
        let full = min(store.earliestDay ?? today, today)...today
        guard let range else { return full }
        return max(range.lowerBound, full.lowerBound)...min(range.upperBound, today)
    }

    var body: some View {
        let _ = store.changeToken
        let days = store.resolvedDays(in: scope)
        let coverage = DayAudit.coverage(days)
        let runs = DayAudit.runs(days).filter { $0.kind == kind }
        let todayYear = EpochDay(value: store.todayEpoch).civil().year

        ZStack {
            Theme.sky.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    coverageCard(coverage)

                    Picker("Show", selection: $kind) {
                        Text("No data · \(coverage.unknown)").tag(DayRun.Kind.unknown)
                        Text("Assumed · \(coverage.inferred)").tag(DayRun.Kind.inferred)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    Text(kind == .unknown
                         ? "Nothing was recorded on these days, so no limit counts them. Say where you were and they count properly."
                         : "Short gaps between two sightings of the same place were filled in for you. Confirm a run to lock it in as your own entry.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)

                    if runs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.good)
                            Text(kind == .unknown ? "No days without data" : "Nothing assumed")
                                .font(Theme.display(16, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    }

                    if kind == .inferred, runs.count > 1 {
                        Button {
                            confirmAll = true
                        } label: {
                            Text("Confirm all \(coverage.inferred) assumed days")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.sky)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(runs) { run in
                        runRow(run, todayYear: todayYear)
                    }
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(Theme.title("Review gaps"))
        .sheet(item: $picking) { run in
            CountryPickerView { code in
                edit.setCountry(code, from: run.startDay, to: run.endDay)
            }
        }
        .confirmationDialog(
            "Confirm every assumed day?", isPresented: $confirmAll, titleVisibility: .visible
        ) {
            Button("Confirm all") {
                for run in runs {
                    if let code = run.assumedCode {
                        edit.setCountry(code, from: run.startDay, to: run.endDay)
                    }
                }
                HapticsDirector.shared.tick()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each assumed day becomes a manual entry for the country shown. You can still change any day on the calendar.")
        }
    }

    private func coverageCard(_ coverage: DayAudit.Coverage) -> some View {
        let total = max(1, coverage.total)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int((coverage.evidencedShare * 100).rounded()))%")
                    .font(Theme.poster(48))
                    .foregroundStyle(Theme.ink)
                Text("of \(coverage.total.grouped) days have direct evidence")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(Theme.ink)
                        .frame(width: max(2, geo.size.width * CGFloat(coverage.evidenced) / CGFloat(total)))
                    Capsule().fill(Theme.aurora1)
                        .frame(width: geo.size.width * CGFloat(coverage.inferred) / CGFloat(total))
                    Capsule().fill(Theme.amber)
                }
            }
            .frame(height: 6)
            HStack(spacing: 14) {
                key(Theme.ink, "Recorded \(coverage.evidenced.grouped)")
                key(Theme.aurora1, "Assumed \(coverage.inferred.grouped)")
                key(Theme.amber, "No data \(coverage.unknown.grouped)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
        .accessibilityElement(children: .combine)
    }

    private func key(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink2)
        }
    }

    private func runRow(_ run: DayRun, todayYear: Int) -> some View {
        let home = store.homeOn(run.startDay)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(DayFormat.shortRange(run.startDay, run.endDay, todayYear: todayYear))
                    .font(Theme.numeric(13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(run.days == 1 ? "1 day" : "\(run.days) days")
                    .font(Theme.figure(12, weight: .bold))
                    .foregroundStyle(run.kind == .unknown ? Theme.amber : Theme.aurora1)
            }
            HStack(spacing: 8) {
                if run.kind == .inferred, let code = run.assumedCode {
                    action("Confirm \(flagEmoji(code)) \(countryName(code))", filled: true) {
                        edit.setCountry(code, from: run.startDay, to: run.endDay)
                    }
                } else if let home {
                    action("\(flagEmoji(home)) At home", filled: true) {
                        edit.setCountry(home, from: run.startDay, to: run.endDay)
                    }
                }
                action("Somewhere else", filled: false) { picking = run }
            }
        }
        .padding(14)
        .nightCard()
    }

    private func action(_ title: String, filled: Bool, _ perform: @escaping () -> Void) -> some View {
        Button {
            perform()
            HapticsDirector.shared.tick()
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(filled ? Theme.sky : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(filled ? AnyShapeStyle(Theme.auroraGradient) : AnyShapeStyle(Color.clear))
                )
                .overlay(Capsule().strokeBorder(filled ? Color.clear : Theme.hairline2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
