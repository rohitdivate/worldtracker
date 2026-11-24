import SwiftUI
import WorldTrackerKit

/// Planned trips, on the Day Limits screen: what you intend to do, so every
/// limit can say where it would leave you.
struct PlansSection: View {
    @State private var editing: EditorTarget?

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var plans: PlanStore { AppContainer.shared.planStore }

    struct EditorTarget: Identifiable {
        let id = UUID()
        let plan: PlannedTrip?
    }

    var body: some View {
        let upcoming = plans.upcoming(today: store.todayEpoch)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Planned trips", actionTitle: "Add") {
                editing = EditorTarget(plan: nil)
            }

            if upcoming.isEmpty {
                Button {
                    editing = EditorTarget(plan: nil)
                } label: {
                    HStack(spacing: 13) {
                        IconTile(symbol: "calendar.badge.plus", tint: Theme.aurora1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("What if I go?")
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text("Add a trip you're considering and every limit shows where it would leave you.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.ink3)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 6)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 13)
                    .nightCard()
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, plan in
                        Button {
                            editing = EditorTarget(plan: plan)
                        } label: {
                            row(plan)
                        }
                        .buttonStyle(.plain)
                        if index < upcoming.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .nightCard()
            }
        }
        .sheet(item: $editing) { target in
            PlanEditorView(plan: target.plan)
        }
        .task { plans.prune(today: store.todayEpoch) }
    }

    private func row(_ plan: PlannedTrip) -> some View {
        let year = EpochDay(value: store.todayEpoch).civil().year
        return HStack(spacing: 12) {
            Text(flagEmoji(plan.countryCode)).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(countryName(plan.countryCode))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(DayFormat.shortRange(plan.startDay, plan.endDay, todayYear: year))
                    .font(Theme.numeric(11, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            Text("\(plan.dayCount)d")
                .font(Theme.figure(13, weight: .bold))
                .foregroundStyle(Theme.aurora1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Add or change a planned trip.
struct PlanEditorView: View {
    private let original: PlannedTrip?

    @Environment(\.dismiss) private var dismiss
    @State private var countryCode: String?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showCountryPicker = false

    private var plans: PlanStore { AppContainer.shared.planStore }

    private static var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    init(plan: PlannedTrip?) {
        original = plan
        let start = plan.map { Self.date($0.startDay) } ?? Self.tomorrow.addingTimeInterval(12 * 3600)
        let end = plan.map { Self.date($0.endDay) }
            ?? Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        _countryCode = State(initialValue: plan?.countryCode)
        _startDate = State(initialValue: max(start, Self.tomorrow))
        _endDate = State(initialValue: max(end, Self.tomorrow))
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        Button {
                            showCountryPicker = true
                        } label: {
                            HStack {
                                Text("Country").foregroundStyle(Theme.ink)
                                Spacer()
                                if let code = countryCode {
                                    Text("\(flagEmoji(code)) \(countryName(code))")
                                        .foregroundStyle(Theme.aurora1)
                                } else {
                                    Text("Select country").foregroundStyle(Theme.ink3)
                                }
                            }
                        }
                        DatePicker("Arrive", selection: $startDate, in: Self.tomorrow..., displayedComponents: .date)
                        DatePicker("Leave", selection: $endDate, in: startDate..., displayedComponents: .date)
                    } footer: {
                        Text("Plans never touch your history. They only feed the forecast on each day limit, and drop away once the dates pass.")
                            .textCase(nil)
                    }

                    if let original {
                        Section {
                            Button("Remove this plan", role: .destructive) {
                                plans.remove(id: original.id)
                                dismiss()
                            }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle(original == nil ? "Planned trip" : "Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(countryCode == nil)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView { countryCode = $0 }
            }
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart { endDate = newStart }
            }
        }
    }

    private func save() {
        guard let code = countryCode else { return }
        let zone = TimeZone.current
        plans.save(PlannedTrip(
            id: original?.id ?? UUID().uuidString,
            countryCode: code,
            startDay: EpochDay(date: startDate, timeZone: zone).value,
            endDay: EpochDay(date: endDate, timeZone: zone).value
        ))
        HapticsDirector.shared.tick()
        dismiss()
    }

    private static func date(_ epochDay: Int) -> Date {
        let c = EpochDay(value: epochDay).civil()
        return Calendar.current.date(
            from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12)
        ) ?? Date()
    }
}

extension DayLimitForecast {
    /// "With plans: peaks at 78 of 90 on 3 Mar 2027"
    func summary(for rule: DayLimitRule) -> String {
        switch rule.goal {
        case .stayUnder:
            if let day = crossingDay {
                return "With plans: over the limit from \(DayFormat.long(day))"
            }
            return "With plans: peaks at \(peakUsed) of \(rule.limit) on \(DayFormat.long(peakDay))"
        case .reachAtLeast:
            if let day = crossingDay {
                return "With plans: reached on \(DayFormat.long(day))"
            }
            return "With plans: \(usedAtEnd) of \(rule.limit) by \(DayFormat.long(endDay))"
        }
    }
}
