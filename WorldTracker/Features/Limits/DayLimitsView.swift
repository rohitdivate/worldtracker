import SwiftUI
import WorldTrackerKit

/// Every day-count rule with its live status, plus one-tap presets.
struct DayLimitsView: View {
    @State private var editing: EditorTarget?

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var limits: DayLimitStore { AppContainer.shared.dayLimitStore }

    struct EditorTarget: Identifiable {
        let id = UUID()
        let rule: DayLimitRule?
    }

    var body: some View {
        let _ = store.changeToken
        let _ = AppContainer.shared.planStore.plans   // forecasts follow the plans
        let statuses = limits.statuses(using: store)
        let suggestions = limits.suggestions(home: store.homeCountry)

        ZStack {
            Theme.sky.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if statuses.isEmpty {
                        intro
                    } else {
                        ForEach(statuses) { status in
                            NavigationLink(value: AppRouter.HomeRoute.limit(status.id)) {
                                LimitRow(
                                    status: status, showsOutlook: true,
                                    forecast: limits.forecast(for: status.rule, using: store)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        PlansSection()
                            .padding(.top, 8)
                    }

                    SectionLabel(title: statuses.isEmpty ? "Start with" : "Add another")
                        .padding(.top, 8)

                    ForEach(suggestions) { rule in
                        presetRow(rule)
                    }
                    customRow

                    Text("Counts come from your recorded days and follow the general shape of each rule. They are a guide for planning, not legal or tax advice: check the official rules for your own situation.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 10)

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                // One readable column, however wide the canvas.
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(Theme.title("Day limits"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = EditorTarget(rule: nil)
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.aurora1)
                }
                .accessibilityLabel("Add a custom limit")
            }
        }
        .sheet(item: $editing) { target in
            DayLimitEditorView(rule: target.rule)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconTile(symbol: "gauge.with.dots.needle.67percent", size: 46, tint: Theme.aurora2)
            Text("How many days do I have left?")
                .font(Theme.display(22, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Pick a rule and Been There counts it from the days it has already logged: no spreadsheet, no typing in trips. Border days and days with no data are handled the way each rule expects.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    private func presetRow(_ rule: DayLimitRule) -> some View {
        Button {
            limits.add(rule)
            HapticsDirector.shared.tick()
        } label: {
            HStack(spacing: 13) {
                IconTile(symbol: symbol(for: rule), tint: Theme.aurora1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.name)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(summary(of: rule))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 6)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.auroraGradient)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .nightCard()
        }
        .buttonStyle(.plain)
    }

    private var customRow: some View {
        Button {
            editing = EditorTarget(rule: nil)
        } label: {
            HStack(spacing: 13) {
                IconTile(symbol: "slider.horizontal.3", tint: Theme.aurora2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom limit")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Any country, any window, any number of days")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .nightCard()
        }
        .buttonStyle(.plain)
    }

    private func symbol(for rule: DayLimitRule) -> String {
        switch rule.scope {
        case .schengen: "star.circle.fill"
        case .outside: "airplane.departure"
        case .country: "calendar.badge.clock"
        }
    }

    private func summary(of rule: DayLimitRule) -> String {
        DayLimitCopy.sentence(for: rule)
    }
}

/// Plain-English descriptions of a rule, shared by the list, the detail
/// screen and the editor preview.
enum DayLimitCopy {
    static func sentence(for rule: DayLimitRule) -> String {
        let what: String
        switch rule.scope {
        case .schengen: what = "days in the Schengen area"
        case .country(let code): what = "days in \(countryNameInSentence(code))"
        case .outside(let code): what = "whole days outside \(countryNameInSentence(code))"
        }
        let verb = rule.goal == .stayUnder ? "No more than" : "At least"
        return "\(verb) \(rule.limit) \(what) in \(windowPhrase(rule.window))"
    }

    static func windowPhrase(_ window: DayLimitWindow) -> String {
        switch window {
        case .rolling(let days): return "any \(days)-day period"
        case .calendarYear: return "a calendar year"
        case .yearStarting(let month, let day):
            let months = DateFormatter().monthSymbols ?? []
            let name = (1...months.count).contains(month) ? months[month - 1] : "?"
            return "a year starting \(day) \(name)"
        }
    }

    static func scopeNoun(_ scope: DayLimitScope) -> String {
        switch scope {
        case .schengen: return "Schengen"
        case .country(let code): return countryName(code)
        case .outside(let code): return "outside \(countryName(code))"
        }
    }
}
