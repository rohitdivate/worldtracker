import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
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
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Version 0.1 · Milestone 1 — offline world atlas")
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
