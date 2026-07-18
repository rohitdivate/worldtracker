import SwiftUI

struct SettingsView: View {
    @Environment(LocationService.self) private var location

    var body: some View {
        @Bindable var location = location
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: Binding(
                        get: { location.smartTrackingEnabled },
                        set: { location.smartTrackingEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart tracking")
                            Text("Automatically logs your country each day using your location.")
                                .font(.footnote)
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .tint(Theme.aurora1)

                    NavigationLink {
                        TrackingHealthView()
                    } label: {
                        Label {
                            Text("Tracking health")
                        } icon: {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundStyle(Theme.aurora1)
                        }
                    }
                } header: {
                    Text("Tracking")
                }

                Section {
                    Label {
                        Text("Everything stays on this device")
                            .foregroundStyle(Theme.ink2)
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Theme.aurora1)
                    }
                    .font(.system(size: 14))
                } header: {
                    Text("Privacy")
                }

                Section {
                    NavigationLink {
                        DeveloperGeoView()
                    } label: {
                        Label {
                            Text("Geo lookup tester")
                        } icon: {
                            Image(systemName: "globe.desk")
                                .foregroundStyle(Theme.aurora2)
                        }
                    }
                    NavigationLink {
                        DeveloperIngestLogView()
                    } label: {
                        Label {
                            Text("Ingest log")
                        } icon: {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(Theme.aurora2)
                        }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Version 0.1 · Milestone 2 — live tracking")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Theme.sky)
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
