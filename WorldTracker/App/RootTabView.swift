import SwiftUI

struct RootTabView: View {
    var body: some View {
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
