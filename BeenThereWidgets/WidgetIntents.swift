import AppIntents
import WidgetKit

// MARK: - Choosing a limit (widget configuration)

/// A day-limit rule as the widget picker shows it. The list comes from the
/// snapshot the app writes, so it is always the user's own rules.
struct LimitEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Day Limit"
    static var defaultQuery = LimitQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct LimitQuery: EntityQuery {
    private func all() -> [LimitEntity] {
        (WidgetSnapshotReader.load()?.limits ?? []).map {
            LimitEntity(id: $0.id, name: $0.name)
        }
    }

    func entities(for identifiers: [String]) async throws -> [LimitEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LimitEntity] {
        all()
    }
}

/// Edit Widget → pick a rule. Left empty, the widget follows whichever
/// limit is most pressing.
struct SelectLimitIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Day Limit"
    static var description = IntentDescription(
        "Pick the limit to show. Leave it empty to follow whichever is closest."
    )

    @Parameter(title: "Limit")
    var limit: LimitEntity?

    init() {}
}

// MARK: - Interactive: Your Top period

enum TopPeriod: String {
    case year
    case allTime

    static let defaultsKey = "widgetTopPeriod"

    static var current: TopPeriod {
        let defaults = UserDefaults(suiteName: WidgetSnapshotReader.appGroupID)
        return TopPeriod(rawValue: defaults?.string(forKey: defaultsKey) ?? "") ?? .year
    }
}

/// Flips Your Top between this year and all time, right on the Home Screen.
/// Runs in the widget process; WidgetKit reloads the timeline afterwards.
struct ToggleTopPeriodIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Your Top period"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: WidgetSnapshotReader.appGroupID)
        let next: TopPeriod = TopPeriod.current == .year ? .allTime : .year
        defaults?.set(next.rawValue, forKey: TopPeriod.defaultsKey)
        return .result()
    }
}

// MARK: - Opening the app (Control Center)

/// Mirror of the app's `BeenThereDestination` and `OpenBeenThereIntent`
/// (WorldTracker/Intents/BeenThereIntents.swift). Controls live in this
/// extension, but an intent that opens the app is performed by the app, so
/// both targets declare the same type and the app's copy does the routing.
/// Keep the type names, case names and parameter in step; the validator
/// compares them.
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

    func perform() async throws -> some IntentResult {
        .result()
    }
}
