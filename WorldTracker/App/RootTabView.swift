import SwiftUI

enum AppTab: Hashable {
    case home, calendar, map, places, settings
}

struct RootTabView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showAlwaysUpgrade = false
    @Environment(\.scenePhase) private var scenePhase

    private var celebration: CelebrationCoordinator {
        AppContainer.shared.celebrationCoordinator
    }

    private var router: AppRouter { AppContainer.shared.router }

    var body: some View {
        @Bindable var router = router
        tabs
            .onAppear { showOnboarding = !onboardingDone }
            .onChange(of: onboardingDone) { _, done in
                if done {
                    showOnboarding = false
                    celebration.presentIfPossible()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    celebration.presentIfPossible()
                    AppContainer.shared.backfillEngine.resumeIfPaused()
                    Task {
                        if await AlwaysPromptGate.shouldOffer() {
                            AlwaysPromptGate.recordShown()
                            showAlwaysUpgrade = true
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openTabDeepLink)) { note in
                guard let tab = note.userInfo?["tab"] as? String,
                      let url = URL(string: "beenthere://\(tab)") else { return }
                router.handle(url)
            }
            .sheet(isPresented: $showAlwaysUpgrade) {
                AlwaysUpgradeSheet()
            }
            .sheet(isPresented: $router.showHomePicker) {
                HomeHistoryView()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                WelcomeFlow()
            }
            .onOpenURL { url in
                // beenthere://<tab> and beenthere://settings/<route> —
                // widgets, notifications, and the setup checklist.
                router.handle(url)
            }
            .overlay {
                if let current = celebration.current {
                    NewCountryCelebrationView(
                        celebration: current,
                        onSeeWorld: {
                            router.open(tab: .map)
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
        @Bindable var router = router
        return TabView(selection: $router.selectedTab) {
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
