import SwiftUI
import WorldTrackerKit

struct SettingsView: View {
    @Environment(LocationService.self) private var location
    @AppStorage("icloudBackup") private var icloudBackup = false
    @AppStorage("icloudBackupFellBack") private var icloudFellBack = false
    @State private var showHomePicker = false
    @State private var confirmErase = false
    @State private var confirmDeleteAll = false
    @State private var showCloudNote = false
    @State private var csvURL: URL?
    @State private var jsonURL: URL?

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var edit: EditService { AppContainer.shared.editService }
    private var export: ExportService { AppContainer.shared.exportService }

    var body: some View {
        let _ = store.changeToken
        NavigationStack {
            List {
                profileSection
                trackingSection
                photosSection
                importSection
                dataSection
                privacySection
                developerSection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Theme.sky)
            .task { regenerateExports() }
            .onChange(of: store.changeToken) { _, _ in regenerateExports() }
            .sheet(isPresented: $showHomePicker) {
                HomeHistoryView()
            }
            .alert("iCloud backup", isPresented: $showCloudNote) {
                Button("OK") {}
            } message: {
                Text("The change applies the next time the app launches. Backup uses your personal iCloud database — nothing is shared with anyone, including the app's author. Requires the iCloud capability (README section 9).")
            }
            .confirmationDialog(
                "Erase auto-detected data?",
                isPresented: $confirmErase,
                titleVisibility: .visible
            ) {
                Button("Erase automatic data", role: .destructive) {
                    edit.eraseAutomaticData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes GPS, photo, imported and inferred history plus places. Manual entries and notes are kept. Photos and imports can rebuild history again any time.")
            }
            .confirmationDialog(
                "Delete ALL data?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    edit.deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everything — including manual edits and notes. This cannot be undone.")
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            Button {
                showHomePicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home base").foregroundStyle(Theme.ink)
                        if store.homeTimeline.periods.count > 1 {
                            Text("\(store.homeTimeline.periods.count) home periods")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    Spacer()
                    if let home = store.homeCountry {
                        Text("\(flagEmoji(home)) \(countryName(home))")
                            .foregroundStyle(Theme.aurora1)
                    } else {
                        Text("Set your country").foregroundStyle(Theme.ink3)
                    }
                }
            }

            Menu {
                Button("Leave empty") { store.gapFillModeRaw = "leaveEmpty" }
                Button("Assume I stayed put") { store.gapFillModeRaw = "assume" }
                Button("Fill short gaps (\(store.gapFillMaxDays) days)") { store.gapFillModeRaw = "short" }
            } label: {
                HStack {
                    Text("Days with no data").foregroundStyle(Theme.ink)
                    Spacer()
                    Text(gapFillLabel).foregroundStyle(Theme.ink2)
                }
            }
        }
    }

    private var gapFillLabel: String {
        switch store.gapFillModeRaw {
        case "leaveEmpty": return "Leave empty"
        case "assume": return "Assume stayed"
        default: return "Fill ≤ \(store.gapFillMaxDays) days"
        }
    }

    private var trackingSection: some View {
        Section("Tracking") {
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
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            NavigationLink {
                PhotoSyncView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time Machine")
                        Text("Rebuild your history from photos")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink3)
                    }
                } icon: {
                    Image(systemName: "photo.stack.fill")
                        .foregroundStyle(Theme.aurora2)
                }
            }
        }
    }

    private var importSection: some View {
        Section {
            NavigationLink {
                ImportTimelineView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Timeline")
                        Text("Import years of Location History")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink3)
                    }
                } icon: {
                    Image(systemName: "map.fill")
                        .foregroundStyle(Theme.aurora2)
                }
            }
            NavigationLink {
                ImportFlightsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flights")
                        Text("Flighty or CSV — closes airplane-mode gaps")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink3)
                    }
                } icon: {
                    Image(systemName: "airplane")
                        .foregroundStyle(Theme.aurora2)
                }
            }
        } header: {
            Text("Import")
        }
    }

    private var dataSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { icloudBackup },
                set: { value in
                    icloudBackup = value
                    icloudFellBack = false
                    showCloudNote = true
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud backup")
                    Text(icloudFellBack
                         ? "Couldn't reach iCloud last launch — check the capability and that you're signed in."
                         : "Your own private iCloud database. Survives a lost phone.")
                        .font(.footnote)
                        .foregroundStyle(icloudFellBack ? Theme.amber : Theme.ink3)
                }
            }
            .tint(Theme.aurora1)

            if let url = csvURL {
                ShareLink(item: url) {
                    Label {
                        Text("Export CSV")
                    } icon: {
                        Image(systemName: "tablecells")
                            .foregroundStyle(Theme.aurora1)
                    }
                }
            }
            if let url = jsonURL {
                ShareLink(item: url) {
                    Label {
                        Text("Export JSON")
                    } icon: {
                        Image(systemName: "curlybraces")
                            .foregroundStyle(Theme.aurora1)
                    }
                }
            }

            Button {
                confirmErase = true
            } label: {
                Text("Erase auto-detected data").foregroundStyle(Theme.amber)
            }
            Button {
                confirmDeleteAll = true
            } label: {
                Text("Delete all my data").foregroundStyle(Theme.alert)
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Exports include every resolved day with provenance — days recorded by iPhone location add credibility with authorities.")
        }
    }

    private func regenerateExports() {
        csvURL = export.exportCSV()
        jsonURL = export.exportJSON()
    }

    private var privacySection: some View {
        Section("Privacy") {
            Label {
                Text("No accounts, no servers, no analytics. Your data lives on this device (and your own iCloud if backup is on).")
                    .foregroundStyle(Theme.ink2)
            } icon: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.aurora1)
            }
            .font(.system(size: 13))
        }
    }

    private var developerSection: some View {
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
            Text("Been There v1.0 · Night Flight")
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
