import Foundation
import Observation
import SwiftUI

/// One place that knows how to get anywhere: tab switches, typed Settings
/// pushes, and the beenthere:// URL scheme (widgets, notifications, and the
/// setup checklist all funnel through here).
@MainActor
@Observable
final class AppRouter {
    enum SettingsRoute: String, Hashable {
        case trackingHealth = "health"
        case timeMachine = "photos"
        case importTimeline = "timeline"
        case importFlights = "flights"
    }

    var selectedTab: AppTab = .home
    var settingsPath: [SettingsRoute] = []
    /// The Home base editor sheet (HomeHistoryView), presentable from anywhere.
    var showHomePicker = false

    func open(tab: AppTab, settings: SettingsRoute? = nil) {
        selectedTab = tab
        if tab == .settings {
            settingsPath = settings.map { [$0] } ?? []
        }
    }

    /// beenthere://<tab> and beenthere://settings/<route>.
    func handle(_ url: URL) {
        guard url.scheme == "beenthere" else { return }
        switch url.host() {
        case "calendar": open(tab: .calendar)
        case "map": open(tab: .map)
        case "places": open(tab: .places)
        case "settings":
            let route = url.pathComponents.dropFirst().first
                .flatMap(SettingsRoute.init(rawValue:))
            open(tab: .settings, settings: route)
        default: open(tab: .home)
        }
    }
}
