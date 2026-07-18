import SwiftUI
import WorldTrackerKit

/// The day sheet, now with authority: see the verdict and every piece of
/// evidence, then overrule it — set the country, clear the day, add a note,
/// or hand it back to the machine.
struct DayEditorView: View {
    let epochDay: Int

    @Environment(\.dismiss) private var dismiss
    @State private var showCountryPicker = false
    @State private var note = ""
    @State private var evidence: DayEvidence?

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var edit: EditService { AppContainer.shared.editService }

    var body: some View {
        let resolved = store.day(epochDay)
        let (y, m, d) = EpochDay(value: epochDay).civil()
        let isManual = resolved.source == .manual
        let isCleared = resolved.countryCodes.isEmpty && !resolved.isFilled && edit.hasClearedAnnotation(day: epochDay)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Verdict
                    if resolved.countryCodes.isEmpty {
                        HStack(spacing: 10) {
                            Circle()
                                .strokeBorder(Theme.ink3, lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                            Text(isCleared ? "Marked as no data" : "No data for this day")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .nightCard()
                    } else {
                        ForEach(resolved.countryCodes, id: \.self) { code in
                            HStack(spacing: 12) {
                                FlagChip(code: code, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(countryName(code))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    if resolved.countryCodes.count >= 2 {
                                        Text("Border-crossing day — counted in both")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.ink3)
                                    }
                                }
                                Spacer()
                                if resolved.isFilled {
                                    Text("FILLED")
                                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(Theme.aurora2)
                                } else if let source = resolved.source {
                                    ProvenanceStamp(source: source)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .nightCard()
                        }
                    }

                    // Evidence
                    if let evidence, !(evidence.facts.isEmpty && evidence.photoPlaces.isEmpty && evidence.locationSampleCount == 0) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("EVIDENCE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(Theme.ink3)

                            ForEach(evidence.facts) { fact in
                                HStack(spacing: 8) {
                                    Text(flagEmoji(fact.countryCode))
                                    Text(countryName(fact.countryCode))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.ink2)
                                    ProvenanceStamp(source: fact.source)
                                    Spacer()
                                    Text("×\(fact.evidenceCount)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.ink3)
                                }
                            }
                            ForEach(evidence.photoPlaces) { place in
                                HStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.aurora2)
                                    Text([place.city, place.countryCode.map(countryName)]
                                        .compactMap { $0 }.joined(separator: ", "))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.ink2)
                                    Spacer()
                                    Text("\(place.photoCount) photos")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.ink3)
                                }
                            }
                            if evidence.locationSampleCount > 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.aurora1)
                                    Text("\(evidence.locationSampleCount) location events")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.ink2)
                                    Spacer()
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .nightCard()
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(Theme.ink3)
                        TextField("Add a note for this day…", text: $note, axis: .vertical)
                            .lineLimit(1...4)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .onSubmit { edit.setNote(note, day: epochDay) }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nightCard()

                    // Actions
                    VStack(spacing: 9) {
                        Button {
                            showCountryPicker = true
                        } label: {
                            Label("Set country for this day", systemImage: "flag.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.sky)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 14))
                        }

                        if isManual || isCleared {
                            Button {
                                edit.revertToAutomatic(day: epochDay)
                                refresh()
                            } label: {
                                Label("Revert to automatic", systemImage: "arrow.uturn.backward")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.aurora1)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Theme.aurora1.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }

                        if !isCleared {
                            Button {
                                edit.clearDay(epochDay)
                                refresh()
                            } label: {
                                Label("Mark as no data", systemImage: "eye.slash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.alert)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Theme.alert.opacity(0.35), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    Text("Manual changes always win over automatic tracking and survive photo re-syncs.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .background(Theme.skyRaised)
            .navigationTitle(dateTitle(year: y, month: m, day: d))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        edit.setNote(note, day: epochDay)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView { code in
                    edit.setCountries([code], day: epochDay)
                    refresh()
                }
            }
            .onAppear {
                note = edit.note(for: epochDay)
                refresh()
            }
        }
    }

    private func refresh() {
        evidence = edit.evidence(for: epochDay)
    }

    private func dateTitle(year: Int, month: Int, day: Int) -> String {
        let formatter = DateFormatter()
        let monthName = formatter.monthSymbols[month - 1]
        return "\(monthName) \(day), \(year)"
    }
}
