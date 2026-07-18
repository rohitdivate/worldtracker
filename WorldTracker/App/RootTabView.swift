import SwiftUI

struct RootTabView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false

    var body: some View {
        tabs
            .onAppear { showOnboarding = !onboardingDone }
            .onChange(of: onboardingDone) { _, done in
                if done { showOnboarding = false }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                WelcomeFlow()
            }
    }

    private var tabs: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Calendar", systemImage: "calendar") {
                HistoryView()
            }
            Tab("Map", systemImage: "globe.europe.africa.fill") {
                WorldMapView()
            }
            Tab("Places", systemImage: "mappin.and.ellipse") {
                PlacesListView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
