import AppIntents
import Foundation
import WorldTrackerKit

/// Siri, Spotlight, Shortcuts and the Action button. Every answer is read
/// from the same on-device ledger the app shows; nothing leaves the phone.

// MARK: - Opening the app

/// Mirror of the widget extension's copy (BeenThereWidgets/WidgetIntents.swift).
/// Control Center buttons live there, but the system performs an
/// open-the-app intent in the app, so this is the copy that routes.
enum BeenThereDestination: String, AppEnum {
    case home
    case calendar
    case world
    case passport
    case limits

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
    static var caseDisplayRepresentations: [BeenThereDestination: DisplayRepresentation] = [
        .home: "Overview",
        .calendar: "Calendar",
        .world: "World",
        .passport: "Passport",
        .limits: "Day Limits",
    ]

    /// The beenthere:// host the router understands.
    var host: String {
        switch self {
        case .home: "home"
        case .calendar: "calendar"
        case .world: "map"
        case .passport: "passport"
        case .limits: "limits"
        }
    }
}

struct OpenBeenThereIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Been There"
    static var description = IntentDescription("Opens Been There on a chosen screen.")
    static var openAppWhenRun = true

    @Parameter(title: "Screen")
    var destination: BeenThereDestination

    init() {
        destination = .home
    }

    init(destination: BeenThereDestination) {
        self.destination = destination
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "beenthere://\(destination.host)") {
            AppContainer.shared.router.handle(url)
        }
        return .result()
    }
}

// MARK: - Answers

/// The sentences Siri speaks, as plain functions. Kept apart from the
/// intents so they can be read on screen (Settings → Developer → Siri
/// answers): the iOS 26.5 simulator cannot execute App Shortcuts at all
/// (FB23504349), so that screen is the only way to check them without a
/// device.
@MainActor
enum SiriAnswers {
    static func whereAmI() -> String {
        let store = AppContainer.shared.ledgerStore
        guard let stay = store.currentStay() else {
            return "Been There hasn't logged a location yet."
        }
        let name = countryNameInSentence(stay.countryCode)
        let yearDays = store.daysThisYear(in: stay.countryCode)
        var line = "You're in \(name), day \(stay.days) of this stay. That's \(yearDays) \(yearDays == 1 ? "day" : "days") there this year."
        if let limit = AppContainer.shared.dayLimitStore.activeStatus(using: store) {
            line += " \(limit.rule.name): \(limit.headline.lowercased())."
        }
        return line
    }

    /// `ruleID` nil = every rule (capped so the answer stays speakable).
    static func dayLimits(ruleID: String? = nil) -> String {
        let store = AppContainer.shared.ledgerStore
        let statuses = AppContainer.shared.dayLimitStore.statuses(using: store)
        guard !statuses.isEmpty else {
            return "You haven't set up a day limit yet. Open Been There and add one from the Overview tab."
        }
        let chosen = ruleID.map { id in statuses.filter { $0.id == id } } ?? statuses
        return chosen.prefix(4)
            .map { "\($0.rule.name): \($0.used) of \($0.rule.limit) days, \($0.headline.lowercased())." }
            .joined(separator: " ")
    }

    static func days(in code: String) -> String {
        let store = AppContainer.shared.ledgerStore
        let name = countryNameInSentence(code)
        guard let stamp = AppContainer.shared.insightsStore.summary(using: store).stamps
            .first(where: { $0.code == code }) else {
            return "Been There has no days logged in \(name)."
        }
        let thisYear = store.daysThisYear(in: code)
        return "\(thisYear) \(thisYear == 1 ? "day" : "days") in \(name) this year, \(stamp.totalDays) in total across \(stamp.visits) \(stamp.visits == 1 ? "visit" : "visits")."
    }
}

// MARK: - Where am I

struct WhereAmIIntent: AppIntent {
    static var title: LocalizedStringResource = "Where Am I"
    static var description = IntentDescription(
        "The country Been There has you in, and how long you've been there."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriAnswers.whereAmI()))
    }
}

// MARK: - Day limits

struct LimitAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Day Limit"
    static var defaultQuery = LimitAppQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct LimitAppQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [LimitAppEntity] {
        AppContainer.shared.dayLimitStore.rules
            .filter { identifiers.contains($0.id) }
            .map { LimitAppEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [LimitAppEntity] {
        AppContainer.shared.dayLimitStore.rules.map { LimitAppEntity(id: $0.id, name: $0.name) }
    }
}

struct CheckDayLimitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Day Limits"
    static var description = IntentDescription(
        "How many days you've used and have left on a limit such as Schengen 90/180."
    )

    @Parameter(title: "Limit")
    var limit: LimitAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Check \(\.$limit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriAnswers.dayLimits(ruleID: limit?.id)))
    }
}

// MARK: - Days in a country

struct CountryAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Country"
    static var defaultQuery = CountryAppQuery()

    /// ISO 3166-1 alpha-2.
    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(flagEmoji(id)) \(countryName(id))")
    }
}

struct CountryAppQuery: EntityStringQuery {
    private static let allCodes: [String] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
        .filter { Locale.current.localizedString(forRegionCode: $0) != nil }

    func entities(for identifiers: [String]) async throws -> [CountryAppEntity] {
        identifiers.map { CountryAppEntity(id: $0) }
    }

    func entities(matching string: String) async throws -> [CountryAppEntity] {
        Self.allCodes
            .filter {
                countryName($0).localizedCaseInsensitiveContains(string)
                    || $0.caseInsensitiveCompare(string) == .orderedSame
            }
            .sorted { countryName($0) < countryName($1) }
            .prefix(20)
            .map { CountryAppEntity(id: $0) }
    }

    /// The countries the user has actually been to, most days first.
    @MainActor
    func suggestedEntities() async throws -> [CountryAppEntity] {
        let store = AppContainer.shared.ledgerStore
        return AppContainer.shared.insightsStore.summary(using: store).stamps
            .sorted { ($0.totalDays, $1.code) > ($1.totalDays, $0.code) }
            .prefix(30)
            .map { CountryAppEntity(id: $0.code) }
    }
}

struct DaysInCountryIntent: AppIntent {
    static var title: LocalizedStringResource = "Days in a Country"
    static var description = IntentDescription(
        "How many days you've spent in a country this year and in total."
    )

    @Parameter(title: "Country")
    var country: CountryAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Count days in \(\.$country)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriAnswers.days(in: country.id)))
    }
}

// MARK: - Shortcuts

struct BeenThereShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhereAmIIntent(),
            phrases: [
                "Where am I in \(.applicationName)",
                "What country am I in with \(.applicationName)",
            ],
            shortTitle: "Where Am I",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: CheckDayLimitsIntent(),
            phrases: [
                "Check my day limits in \(.applicationName)",
                "How many days do I have left in \(.applicationName)",
            ],
            shortTitle: "Day Limits",
            systemImageName: "gauge.with.dots.needle.67percent"
        )
        AppShortcut(
            intent: DaysInCountryIntent(),
            phrases: [
                "Count my days in a country with \(.applicationName)",
                "How many days in \(\.$country) with \(.applicationName)",
            ],
            shortTitle: "Days in a Country",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: OpenBeenThereIntent(),
            phrases: [
                "Open \(\.$destination) in \(.applicationName)",
            ],
            shortTitle: "Open a Screen",
            systemImageName: "arrow.up.forward.app"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .teal
}
