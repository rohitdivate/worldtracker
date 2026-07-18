import SwiftUI

enum AppTab: Hashable {
    case home, calendar, map, places, settings
}

struct RootTabView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var selectedTab: AppTab = .home
    @Environment(\.scenePhase) private var scenePhase

    private var celebration: CelebrationCoordinator {
        AppContainer.shared.celebrationCoordinator
    }

    var body: some View {
        tabs
            .onAppear { showOnboarding = !onboardingDone }
            .onChange(of: onboardingDone) { _, done in
                if done {
                    showOnboarding = false
                    celebration.presentIfPossible()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { celebration.presentIfPossible() }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                WelcomeFlow()
            }
            .onOpenURL { url in
                // beenthere://<tab> — the widgets' deep links.
                guard url.scheme == "beenthere" else { return }
                switch url.host() {
                case "calendar": selectedTab = .calendar
                case "map": selectedTab = .map
                case "places": selectedTab = .places
                case "settings": selectedTab = .settings
                default: selectedTab = .home
                }
            }
            .overlay {
                if let current = celebration.current {
                    NewCountryCelebrationView(
                        celebration: current,
                        onSeeWorld: {
                            selectedTab = .map
                            celebration.dismissCurrent()
                        },
                        onDismiss: { celebration.dismissCurrent() }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: celebration.current)
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                HistoryView()
            }
            Tab("Map", systemImage: "globe.europe.africa.fill", value: AppTab.map) {
                WorldMapView()
            }
            Tab("Places", systemImage: "mappin.and.ellipse", value: AppTab.places) {
                PlacesListView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
