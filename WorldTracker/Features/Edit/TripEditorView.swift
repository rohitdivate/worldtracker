import SwiftUI
import WorldTrackerKit

/// Manual trip entry/editing: country + date range → manual facts for every
/// day. When prefilled with an existing trip, saving replaces the old range
/// (no orphaned days when a trip shrinks or moves).
struct TripEditorView: View {
    struct Prefill {
        let countryCode: String
        let startDay: Int
        let endDay: Int
    }

    private let prefill: Prefill?
    private let onDelete: (() -> Void)?
    private let onSaved: ((String, ClosedRange<Int>) -> Void)?

    init(
        prefill: Prefill? = nil,
        onDelete: (() -> Void)? = nil,
        onSaved: ((String, ClosedRange<Int>) -> Void)? = nil
    ) {
        self.prefill = prefill
        self.onDelete = onDelete
        self.onSaved = onSaved
        _countryCode = State(initialValue: prefill?.countryCode)
        _startDate = State(initialValue: prefill.map { Self.date(fromEpochDay: $0.startDay) } ?? Date())
        _endDate = State(initialValue: prefill.map { Self.date(fromEpochDay: $0.endDay) } ?? Date())
    }

    @Environment(\.dismiss) private var dismiss
    @State private var countryCode: String?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showCountryPicker = false

    private var edit: EditService { AppContainer.shared.editService }

    var body: some View {
        NavigationStack {
            Form {
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

                    DatePicker("Start date", selection: $startDate, in: ...latestPickableDate, displayedComponents: .date)
                    DatePicker("End date", selection: $endDate, in: startDate...latestPickableDate, displayedComponents: .date)
                } footer: {
                    Text(prefill == nil
                         ? "Every day in the range is marked with this country. Manual entries outrank automatic tracking and survive photo re-syncs."
                         : "Saving rewrites the whole trip as manual days — they outrank automatic tracking and survive photo re-syncs.")
                }

                if let onDelete {
                    Section {
                        Button("Delete trip", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(prefill == nil ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(countryCode == nil)
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView { code in
                    countryCode = code
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.sky)
        }
    }

    /// The tracker records the past: everything derives over
    /// earliest...today, so a future date would save facts no view shows.
    private var latestPickableDate: Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        return (startOfTomorrow ?? Date()).addingTimeInterval(-1)
    }

    private func save() {
        guard let code = countryCode else { return }
        let tz = TimeZone.current
        let start = EpochDay(date: startDate, timeZone: tz).value
        let end = EpochDay(date: endDate, timeZone: tz).value
        let range = min(start, end)...max(start, end)
        if let prefill {
            // Bucket the days the edit removes BEFORE anything is written —
            // and by the trip's ORIGINAL country, in case the editor also
            // changed the country.
            let original = prefill.startDay...prefill.endDay
            let store = AppContainer.shared.ledgerStore
            let plan = TripEditPlanner.plan(
                removingCountry: prefill.countryCode,
                from: original,
                keeping: range,
                resolvedCodes: { store.day($0).countryCodes }
            )
            edit.replaceTrip(originalRange: original, with: code, newRange: range, reassigning: plan)
        } else {
            edit.setCountry(code, from: range.lowerBound, to: range.upperBound)
        }
        onSaved?(code, range)
        dismiss()
    }

    private static func date(fromEpochDay day: Int) -> Date {
        let (year, month, dayOfMonth) = EpochDay(value: day).civil()
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = dayOfMonth
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date()
    }
}

#Preview {
    TripEditorView()
        .preferredColorScheme(.dark)
}
