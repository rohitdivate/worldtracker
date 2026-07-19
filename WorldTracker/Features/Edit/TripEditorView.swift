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

    init(prefill: Prefill? = nil, onDelete: (() -> Void)? = nil) {
        self.prefill = prefill
        self.onDelete = onDelete
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

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
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

    private func save() {
        guard let code = countryCode else { return }
        let tz = TimeZone.current
        let start = EpochDay(date: startDate, timeZone: tz).value
        let end = EpochDay(date: endDate, timeZone: tz).value
        let range = min(start, end)...max(start, end)
        if let prefill {
            edit.replaceTrip(
                originalRange: prefill.startDay...prefill.endDay,
                with: code,
                newRange: range
            )
        } else {
            edit.setCountry(code, from: range.lowerBound, to: range.upperBound)
        }
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
