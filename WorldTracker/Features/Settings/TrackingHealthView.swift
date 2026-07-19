import CoreLocation
import SwiftUI
import UIKit

/// The dashboard that prevents "it missed my trip" — every prerequisite for
/// reliable tracking, with a fix-it path when something's wrong.
struct TrackingHealthView: View {
    @Environment(LocationService.self) private var location
    @State private var stats = IngestStats()

    var body: some View {
        List {
            Section("Requirements") {
                healthRow(
                    title: "Location access",
                    ok: location.authorizationStatus == .authorizedAlways,
                    okText: "Always ✓",
                    warnText: warnTextForAuth,
                    fix: openSettings
                )
                healthRow(
                    title: "Precise location",
                    ok: location.accuracyAuthorization == .fullAccuracy,
                    okText: "On ✓",
                    warnText: "Reduced — places won't be detected",
                    fix: openSettings
                )
                healthRow(
                    title: "Background App Refresh",
                    ok: location.backgroundRefreshStatus == .available,
                    okText: "On ✓",
                    warnText: "Off — background tracking is disabled by iOS",
                    fix: openSettings
                )
            }

            Section("Activity") {
                LabeledContent("Samples recorded") {
                    Text("\(stats.totalSamples)")
                        .foregroundStyle(Theme.aurora1)
                        .fontWeight(.semibold)
                }
                LabeledContent("Last event") {
                    if let last = stats.lastEventDate {
                        Text("\(last.formatted(.relative(presentation: .named))) · \(stats.lastEventKind ?? "")")
                            .foregroundStyle(Theme.ink2)
                    } else {
                        Text("None yet").foregroundStyle(Theme.ink3)
                    }
                }
                if !stats.lastEventPlace.isEmpty {
                    LabeledContent("Last place") {
                        Text(stats.lastEventPlace).foregroundStyle(Theme.ink2)
                    }
                }
            }

            Section {
                if location.authorizationStatus == .authorizedWhenInUse {
                    Button(AlwaysPromptGate.systemPromptUsed
                           ? "Allow Always access in iOS Settings"
                           : "Upgrade to Always access") {
                        if AlwaysPromptGate.systemPromptUsed {
                            openSettings()
                        } else {
                            AlwaysPromptGate.markSystemPromptUsed()
                            location.requestAlwaysUpgrade()
                        }
                    }
                    .foregroundStyle(Theme.aurora1)
                }
                Button("Open iOS Settings") {
                    openSettings()
                }
                .foregroundStyle(Theme.aurora2)
            } footer: {
                Text("Don't force-quit the app (swipe it away) — iOS then stops waking it for location events. It uses no meaningful battery when left alone.")
            }
        }
        .navigationTitle("Tracking health")
        .scrollContentBackground(.hidden)
        .background(Theme.sky)
        .task {
            stats = await AppContainer.shared.ingestor.stats()
        }
        .refreshable {
            stats = await AppContainer.shared.ingestor.stats()
        }
    }

    private var warnTextForAuth: String {
        switch location.authorizationStatus {
        case .authorizedWhenInUse: return "While Using — logs only when opened"
        case .denied: return "Denied — tracking is off"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested yet"
        default: return "—"
        }
    }

    private func healthRow(
        title: String,
        ok: Bool,
        okText: String,
        warnText: String,
        fix: @escaping () -> Void
    ) -> some View {
        HStack {
            Circle()
                .fill(ok ? Theme.good : Theme.amber)
                .frame(width: 9, height: 9)
                .shadow(color: (ok ? Theme.good : Theme.amber).opacity(0.7), radius: 5)
            Text(title)
            Spacer()
            if ok {
                Text(okText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.good)
            } else {
                Button(warnText) { fix() }
                    .font(.footnote)
                    .foregroundStyle(Theme.amber)
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
