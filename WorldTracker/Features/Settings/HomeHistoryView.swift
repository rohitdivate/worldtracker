import SwiftUI
import WorldTrackerKit

/// Where you've lived, over time. The first entry is your original home;
/// each move adds a dated change. Stats judge every day against the home
/// that was true THAT day, so years lived abroad never read as travel.
struct HomeHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    private struct DraftMove: Identifiable, Equatable {
        let id = UUID()
        var countryCode: String
        var date: Date
    }

    @State private var firstHome: String?
    @State private var moves: [DraftMove] = []
    @State private var pickingFirstHome = false
    @State private var addingMove = false
    @State private var editingMove: DraftMove?

    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        pickingFirstHome = true
                    } label: {
                        HStack {
                            Text("Originally from").foregroundStyle(Theme.ink)
                            Spacer()
                            if let firstHome {
                                Text("\(flagEmoji(firstHome)) \(countryName(firstHome))")
                                    .foregroundStyle(Theme.aurora1)
                            } else {
                                Text("Pick a country").foregroundStyle(Theme.ink3)
                            }
                        }
                    }
                } footer: {
                    Text("Your home from the beginning of your history until your first move.")
                }

                Section("Moves") {
                    if moves.isEmpty {
                        Text("No moves — one home for your whole history.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink3)
                    }
                    ForEach(sortedMoves) { move in
                        Button {
                            editingMove = move
                        } label: {
                            HStack {
                                Text("\(flagEmoji(move.countryCode)) \(countryName(move.countryCode))")
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("since \(move.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.ink2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ordered = sortedMoves
                        for offset in offsets {
                            moves.removeAll { $0.id == ordered[offset].id }
                        }
                    }

                    Button {
                        addingMove = true
                    } label: {
                        Label("I moved", systemImage: "plus")
                            .foregroundStyle(Theme.aurora1)
                    }
                } footer: {
                    Text("Each move sets your home from that date until the next move. Travel stats, the trips list, and your Year in Travel all follow this history.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.sky)
            .navigationTitle("Home history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(firstHome == nil && moves.isEmpty)
                }
            }
            .sheet(isPresented: $pickingFirstHome) {
                CountryPickerView { code in firstHome = code }
            }
            .sheet(isPresented: $addingMove) {
                MoveEditorSheet(title: "I moved to…") { code, date in
                    moves.append(DraftMove(countryCode: code, date: date))
                }
            }
            .sheet(item: $editingMove) { move in
                MoveEditorSheet(
                    title: "Edit move",
                    initialCountry: move.countryCode,
                    initialDate: move.date,
                    onDelete: { moves.removeAll { $0.id == move.id } }
                ) { code, date in
                    if let index = moves.firstIndex(where: { $0.id == move.id }) {
                        moves[index].countryCode = code
                        moves[index].date = date
                    }
                }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private var sortedMoves: [DraftMove] {
        moves.sorted { $0.date < $1.date }
    }

    private func load() {
        let timeline = store.homeTimeline
        guard !timeline.isEmpty else { return }
        var periods = timeline.periods
        if periods.first?.startDay == nil {
            firstHome = periods.removeFirst().countryCode
        }
        moves = periods.compactMap { period in
            guard let start = period.startDay else { return nil }
            let (y, m, d) = EpochDay(value: start).civil()
            var components = DateComponents()
            components.year = y
            components.month = m
            components.day = d
            guard let date = Calendar.current.date(from: components) else { return nil }
            return DraftMove(countryCode: period.countryCode, date: date)
        }
    }

    private func save() {
        var periods: [HomePeriod] = []
        if let firstHome {
            periods.append(HomePeriod(startDay: nil, countryCode: firstHome))
        }
        for move in sortedMoves {
            let day = EpochDay(date: move.date, timeZone: TimeZone.current).value
            periods.append(HomePeriod(startDay: day, countryCode: move.countryCode))
        }
        store.homeTimeline = HomeTimeline(periods: periods)
        dismiss()
    }
}

/// Country + date pair for one move.
private struct MoveEditorSheet: View {
    let title: String
    var initialCountry: String?
    var initialDate: Date = Date()
    var onDelete: (() -> Void)? = nil
    let onSave: (String, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var countryCode: String?
    @State private var date = Date()
    @State private var pickingCountry = false

    var body: some View {
        NavigationStack {
            Form {
                Button {
                    pickingCountry = true
                } label: {
                    HStack {
                        Text("Country").foregroundStyle(Theme.ink)
                        Spacer()
                        if let countryCode {
                            Text("\(flagEmoji(countryCode)) \(countryName(countryCode))")
                                .foregroundStyle(Theme.aurora1)
                        } else {
                            Text("Pick").foregroundStyle(Theme.ink3)
                        }
                    }
                }
                DatePicker("Moved on", selection: $date, in: ...Date(), displayedComponents: .date)

                if let onDelete {
                    Button("Remove this move", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.sky)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let countryCode {
                            onSave(countryCode, date)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(countryCode == nil)
                }
            }
            .sheet(isPresented: $pickingCountry) {
                CountryPickerView { code in countryCode = code }
            }
            .onAppear {
                countryCode = initialCountry
                date = initialDate
            }
        }
        .preferredColorScheme(.dark)
    }
}
