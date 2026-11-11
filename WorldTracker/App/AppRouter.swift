import Foundation
import Observation
import SwiftUI

/// One place that knows how to get anywhere: tab switches, typed pushes, and
/// the beenthere:// URL scheme (widgets, controls, notifications, Siri and
/// the setup checklist all funnel through here).
@MainActor
@Observable
final class AppRouter {
    enum SettingsRoute: String, Hashable {
        case trackingHealth = "health"
        case timeMachine = "photos"
        case importTimeline = "timeline"
        case importFlights = "flights"
        case gaps
    }

    /// Screens pushed onto Home's stack.
    enum HomeRoute: Hashable {
        case limits
        case limit(String)
        /// Days without direct evidence inside an epoch-day range.
        case gaps(Int, Int)
    }

    /// The three faces of the World tab. Places used to be its own tab.
    enum WorldMode: String, CaseIterable, Hashable {
        case globe = "Globe"
        case countries = "Countries"
        case places = "Places"
    }

    var selectedTab: AppTab = .home
    var settingsPath: [SettingsRoute] = []
    /// Home's navigation stack. A `NavigationPath` because Home pushes
    /// country codes and trip segments as well as `HomeRoute`s.
    var homePath = NavigationPath()
    var worldMode: WorldMode = .globe
    /// The Home base editor sheet (HomeHistoryView), presentable from anywhere.
    var showHomePicker = false

    func open(tab: AppTab, settings: SettingsRoute? = nil) {
        selectedTab = tab
        if tab == .settings {
            settingsPath = settings.map { [$0] } ?? []
        }
    }

    func openWorld(_ mode: WorldMode) {
        worldMode = mode
        selectedTab = .map
    }

    /// Day Limits, optionally straight to one rule.
    func openLimits(ruleID: String? = nil) {
        selectedTab = .home
        var path = NavigationPath([HomeRoute.limits])
        if let ruleID { path.append(HomeRoute.limit(ruleID)) }
        homePath = path
    }

    /// beenthere://<tab>, beenthere://settings/<route>, beenthere://limits/<id>.
    func handle(_ url: URL) {
        guard url.scheme == "beenthere" else { return }
        switch url.host() {
        case "calendar": open(tab: .calendar)
        case "map": openWorld(.globe)
        case "countries": openWorld(.countries)
        case "places": openWorld(.places)
        case "passport": open(tab: .passport)
        case "wrapped":
            // Home owns the story; give it a beat to load its years.
            open(tab: .home)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NotificationCenter.default.post(name: .openWrapped, object: nil)
            }
        case "limits":
            openLimits(ruleID: url.pathComponents.dropFirst().first)
        case "settings":
            let route = url.pathComponents.dropFirst().first
                .flatMap(SettingsRoute.init(rawValue:))
            open(tab: .settings, settings: route)
        default: open(tab: .home)
        }
    }
}
