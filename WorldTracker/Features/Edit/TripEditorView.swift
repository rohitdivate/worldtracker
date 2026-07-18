import SwiftUI
import WorldTrackerKit

/// Manual trip entry: country + date range → manual facts for every day.
struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var countryCode: String?
    @State private var startDate = Date()
    @State private var endDate = Date()
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
                    Text("Every day in the range is marked with this country. Manual entries outrank automatic tracking and survive photo re-syncs.")
                }
            }
            .navigationTitle("New trip")
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
        edit.setCountry(code, from: min(start, end), to: max(start, end))
        dismiss()
    }
}

#Preview {
    TripEditorView()
        .preferredColorScheme(.dark)
}
