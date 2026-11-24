import SwiftUI

enum AppTab: Hashable {
    case home, calendar, map, passport, settings
}

struct RootTabView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @State private var showAlwaysUpgrade = false
    /// Cold-launch only (@State lives for the process) — and only once
    /// onboarded; first-run users go straight to the welcome flow.
    @State private var showLaunchOverlay = UserDefaults.standard.bool(forKey: "onboardingDone")
    @Environment(\.scenePhase) private var scenePhase

    private var celebration: CelebrationCoordinator {
        AppContainer.shared.celebrationCoordinator
    }

    private var router: AppRouter { AppContainer.shared.router }

    var body: some View {
        @Bindable var router = router
        tabs
            .onAppear {
                showOnboarding = !onboardingDone
                #if DEBUG
                // QA aid: `simctl launch <device> <bundle> -debugOpen beenthere://passport`
                // lands on a screen without a tap (launch arguments surface
                // as defaults). Screenshot runs and simulators nobody is
                // driving by hand use it.
                // `-debugBackupTo <path>` / `-debugRestoreFrom <path>`: write
                // or merge a backup at a host path, for moving a ledger
                // between simulators without the share sheet.
                let backup = AppContainer.shared.backupService
                if let path = UserDefaults.standard.string(forKey: "debugBackupTo"),
                   let data = try? backup.makeArchive().encoded() {
                    try? data.write(to: URL(fileURLWithPath: path))
                }
                if let path = UserDefaults.standard.string(forKey: "debugRestoreFrom") {
                    let outcome = (try? backup.restore(from: URL(fileURLWithPath: path)).message)
                        ?? "restore failed"
                    try? Data(outcome.utf8).write(to: URL(fileURLWithPath: path + ".result"))
                }
                if let link = UserDefaults.standard.string(forKey: "debugOpen"),
                   let url = URL(string: link) {
                    showLaunchOverlay = false
                    router.handle(url)
                }
                #endif
            }
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
                switch celebration.current {
                case .newCountry(let moment):
                    NewCountryCelebrationView(
                        celebration: moment,
                        onSeeWorld: {
                            router.openWorld(.globe)
                            celebration.dismissCurrent()
                        },
                        onDismiss: { celebration.dismissCurrent() }
                    )
                    .transition(.opacity)
                case .milestone(let moment):
                    MilestoneCelebrationView(
                        moment: moment,
                        onSeeWorld: {
                            router.openWorld(.globe)
                            celebration.dismissCurrent()
                        },
                        onDismiss: { celebration.dismissCurrent() }
                    )
                    .transition(.opacity)
                case nil:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: celebration.current)
            .overlay {
                if showLaunchOverlay {
                    LaunchOverlayView {
                        showLaunchOverlay = false
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
                }
            }
            .animation(.easeOut(duration: 0.5), value: showLaunchOverlay)
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
            Tab("World", systemImage: "globe.europe.africa.fill", value: AppTab.map) {
                WorldMapView()
            }
            Tab("Passport", systemImage: "book.closed.fill", value: AppTab.passport) {
                PassportView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        // Everything you press answers back.
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        .sensoryFeedback(.selection, trigger: router.worldMode)
    }
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
