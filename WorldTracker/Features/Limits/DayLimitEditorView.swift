import SwiftUI
import WorldTrackerKit

/// Create or edit a day-count rule. The form is the three questions a rule
/// answers: which days count, over what period, and against what number.
struct DayLimitEditorView: View {
    enum ScopeKind: String, CaseIterable, Identifiable {
        case country = "Days in a country"
        case schengen = "Days in Schengen"
        case outside = "Days away from a country"
        var id: String { rawValue }
    }

    enum WindowKind: String, CaseIterable, Identifiable {
        case rolling = "Rolling period"
        case calendarYear = "Calendar year"
        case customYear = "Year starting on a date"
        var id: String { rawValue }
    }

    private let original: DayLimitRule?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var scopeKind: ScopeKind
    @State private var countryCode: String?
    @State private var windowKind: WindowKind
    @State private var rollingDays: Int
    @State private var startMonth: Int
    @State private var startDay: Int
    @State private var limit: Int
    @State private var goal: DayLimitGoal
    @State private var showCountryPicker = false

    private var limits: DayLimitStore { AppContainer.shared.dayLimitStore }

    init(rule: DayLimitRule?) {
        original = rule
        let home = AppContainer.shared.ledgerStore.homeCountry

        var scopeKind = ScopeKind.country
        var country = home
        switch rule?.scope {
        case .schengen: scopeKind = .schengen
        case .country(let code): scopeKind = .country; country = code
        case .outside(let code): scopeKind = .outside; country = code
        case nil: break
        }

        var windowKind = WindowKind.calendarYear
        var rolling = 180
        var month = 4
        var day = 6
        switch rule?.window {
        case .rolling(let days): windowKind = .rolling; rolling = days
        case .calendarYear, nil: break
        case .yearStarting(let m, let d): windowKind = .customYear; month = m; day = d
        }

        _name = State(initialValue: rule?.name ?? "")
        _scopeKind = State(initialValue: scopeKind)
        _countryCode = State(initialValue: country)
        _windowKind = State(initialValue: windowKind)
        _rollingDays = State(initialValue: rolling)
        _startMonth = State(initialValue: month)
        _startDay = State(initialValue: day)
        _limit = State(initialValue: rule?.limit ?? 183)
        _goal = State(initialValue: rule?.goal ?? .stayUnder)
    }

    // MARK: - Derived rule

    private var scope: DayLimitScope? {
        switch scopeKind {
        case .schengen: return .schengen
        case .country: return countryCode.map(DayLimitScope.country)
        case .outside: return countryCode.map(DayLimitScope.outside)
        }
    }

    private var window: DayLimitWindow {
        switch windowKind {
        case .rolling: return .rolling(days: rollingDays)
        case .calendarYear: return .calendarYear
        case .customYear: return .yearStarting(month: startMonth, day: startDay)
        }
    }

    private var windowLength: Int {
        if case .rolling(let days) = window { return days }
        return 366
    }

    private var suggestedName: String {
        guard let scope else { return "" }
        switch scope {
        case .schengen: return "Schengen \(limit)/\(windowLength)"
        case .country(let code): return "\(limit) days in \(countryNameInSentence(code))"
        case .outside(let code): return "\(countryName(code)) absences"
        }
    }

    private var draft: DayLimitRule? {
        guard let scope else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return DayLimitRule(
            id: original?.id ?? UUID().uuidString,
            name: trimmed.isEmpty ? suggestedName : trimmed,
            scope: scope,
            window: window,
            limit: limit,
            goal: goal
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                Section {
                    Picker("Count", selection: $scopeKind) {
                        ForEach(ScopeKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if scopeKind != .schengen {
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
                    }
                } header: {
                    Text("Which days count")
                } footer: {
                    Text(scopeFootnote)
                        .textCase(nil)
                }

                Section("Over what period") {
                    Picker("Period", selection: $windowKind) {
                        ForEach(WindowKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    switch windowKind {
                    case .rolling:
                        Stepper(value: $rollingDays, in: 7...1100, step: rollingDays >= 60 ? 5 : 1) {
                            HStack {
                                Text("Length")
                                Spacer()
                                Text("\(rollingDays) days").foregroundStyle(Theme.aurora1)
                            }
                        }
                    case .calendarYear:
                        EmptyView()
                    case .customYear:
                        Picker("Month", selection: $startMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(DateFormatter().monthSymbols[month - 1]).tag(month)
                            }
                        }
                        Stepper(value: $startDay, in: 1...28) {
                            HStack {
                                Text("Day")
                                Spacer()
                                Text("\(startDay)").foregroundStyle(Theme.aurora1)
                            }
                        }
                    }
                }

                Section {
                    Picker("Goal", selection: $goal) {
                        Text("Stay under").tag(DayLimitGoal.stayUnder)
                        Text("Reach at least").tag(DayLimitGoal.reachAtLeast)
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $limit, in: 1...max(1, windowLength)) {
                        HStack {
                            Text("Days")
                            Spacer()
                            Text("\(limit)").foregroundStyle(Theme.aurora1)
                        }
                    }
                } header: {
                    Text("Against what number")
                } footer: {
                    if let draft {
                        Text(DayLimitCopy.sentence(for: draft) + ".")
                    }
                }

                Section("Name") {
                    TextField(suggestedName.isEmpty ? "Name" : suggestedName, text: $name)
                }
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle(original == nil ? "New limit" : "Edit limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let draft else { return }
                        limits.update(draft)
                        HapticsDirector.shared.tick()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft == nil)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView { code in
                    countryCode = code
                }
            }
            .onChange(of: windowKind) { _, _ in
                limit = min(limit, windowLength)
            }
            .onChange(of: rollingDays) { _, _ in
                limit = min(limit, windowLength)
            }
        }
    }

    private var scopeFootnote: String {
        switch scopeKind {
        case .country:
            return "Any day you were in the country counts, including the days you arrived and left."
        case .schengen:
            return "Any day in any of the 29 Schengen states counts, including arrival and departure days."
        case .outside:
            return "Only whole days away count. The day you leave and the day you return touch the country, so they don't."
        }
    }
}
