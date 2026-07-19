import CoreLocation
import Observation
import SwiftUI
import WorldTrackerKit

/// "Finish setting up" state — derived live from the real services (auth
/// status, home timeline, checkpoints) so it can never drift; the only
/// stored flags are the user's own choices (skip/dismiss).
@MainActor
@Observable
final class SetupChecklist {
    enum Item: String, CaseIterable {
        case location, home, photos, timeline
    }

    enum Status {
        case done, limited, pending, skipped
    }

    struct Entry: Identifiable {
        var id: Item { item }
        let item: Item
        let status: Status
    }

    /// Async-refreshed bits (checkpoints live behind actors).
    private var photosDone = false
    private var timelineImported = false

    private var dismissed: Bool {
        UserDefaults.standard.bool(forKey: "setupChecklistDismissed")
    }

    private var timelineSkipped: Bool {
        UserDefaults.standard.bool(forKey: "checklistSkipped-timeline")
    }

    private func locationStatus() -> Status {
        let location = AppContainer.shared.locationService
        guard location.smartTrackingEnabled else { return .pending }
        switch location.authorizationStatus {
        case .authorizedAlways: return .done
        case .authorizedWhenInUse: return .limited
        default: return .pending
        }
    }

    var entries: [Entry] {
        let store = AppContainer.shared.ledgerStore
        _ = store.changeToken
        return [
            Entry(item: .location, status: locationStatus()),
            Entry(item: .home, status: store.homeTimeline.isEmpty ? .pending : .done),
            Entry(item: .photos, status: photosDone ? .done : .pending),
            Entry(item: .timeline, status: timelineImported ? .done
                                         : timelineSkipped ? .skipped : .pending),
        ]
    }

    /// The card leaves for good once every row is settled (While-Using counts
    /// as settled here — the persistent tracking pill owns that nag).
    var isComplete: Bool {
        entries.allSatisfy { $0.status == .done || $0.status == .limited || $0.status == .skipped }
    }

    var isVisible: Bool {
        !dismissed && !isComplete
    }

    func skipTimeline() {
        UserDefaults.standard.set(true, forKey: "checklistSkipped-timeline")
    }

    func dismiss() {
        UserDefaults.standard.set(true, forKey: "setupChecklistDismissed")
    }

    func refresh() async {
        let container = AppContainer.shared
        let backfill = await container.backfillEngine.lastSync()
        let timeline = await container.importEngine.lastCheckpoint(origin: .timeline)
        let flights = await container.importEngine.lastCheckpoint(origin: .flight)
        photosDone = backfill?.status == "done"
        timelineImported = timeline != nil || flights != nil
    }
}

/// The Home card that walks a new user to full value: each row deep-links
/// straight to its fix.
struct SetupChecklistCard: View {
    let checklist: SetupChecklist
    let onLocation: () -> Void
    let onHome: () -> Void
    let onPhotos: () -> Void
    let onTimeline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("FINISH SETTING UP")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.aurora1)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        checklist.dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .padding(.bottom, 6)

            ForEach(checklist.entries) { entry in
                row(entry)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    @ViewBuilder
    private func row(_ entry: SetupChecklist.Entry) -> some View {
        let settled = entry.status == .done || entry.status == .limited || entry.status == .skipped
        Button {
            if !settled { action(for: entry.item)() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon(for: entry.status))
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor(for: entry.status))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title(for: entry.item))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(settled ? Theme.ink2 : Theme.ink)
                    Text(subtitle(for: entry))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer()
                if !settled {
                    if entry.item == .timeline {
                        Button("Skip") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                checklist.skipTimeline()
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .buttonStyle(.plain)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.aurora1)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(settled)
    }

    private func action(for item: SetupChecklist.Item) -> () -> Void {
        switch item {
        case .location: return onLocation
        case .home: return onHome
        case .photos: return onPhotos
        case .timeline: return onTimeline
        }
    }

    private func icon(for status: SetupChecklist.Status) -> String {
        switch status {
        case .done: return "checkmark.circle.fill"
        case .limited: return "exclamationmark.circle.fill"
        case .pending: return "circle"
        case .skipped: return "minus.circle"
        }
    }

    private func iconColor(for status: SetupChecklist.Status) -> Color {
        switch status {
        case .done: return Theme.good
        case .limited: return Theme.amber
        case .pending: return Theme.ink3
        case .skipped: return Theme.ink3
        }
    }

    private func title(for item: SetupChecklist.Item) -> String {
        switch item {
        case .location: return "Location tracking"
        case .home: return "Home country"
        case .photos: return "Photo history"
        case .timeline: return "Google Timeline"
        }
    }

    private func subtitle(for entry: SetupChecklist.Entry) -> String {
        switch (entry.item, entry.status) {
        case (.location, .done): return "Always on — days log themselves"
        case (.location, .limited): return "While Using — background upgrade available"
        case (.location, _): return "Turn on to log each day automatically"
        case (.home, .done): return "Days at home won't count as travel"
        case (.home, _): return "Keeps every travel stat honest"
        case (.photos, .done): return "History rebuilt from your photos"
        case (.photos, _): return "Rebuild years of trips in a minute"
        case (.timeline, .done): return "Location History imported"
        case (.timeline, .skipped): return "Skipped — anytime in Settings"
        case (.timeline, _): return "Optional: the richest source of past travel"
        }
    }
}

/// Empty states that teach: every "nothing here yet" screen offers the two
/// fastest routes to a full history instead of describing the void.
struct EmptyStateCTAs: View {
    var icon: String = "sparkles"
    let title: String
    let message: String
    var extraTitle: String?
    var extraAction: (() -> Void)?

    private var router: AppRouter { AppContainer.shared.router }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(Theme.auroraGradient)
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)

            Button {
                router.open(tab: .settings, settings: .timeMachine)
            } label: {
                Text("Rebuild from photos")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 13))
            }
            Button {
                router.open(tab: .settings, settings: .importTimeline)
            } label: {
                Text("Import Google Timeline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.aurora1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(Theme.aurora1.opacity(0.5), lineWidth: 1)
                    )
            }
            if let extraTitle, let extraAction {
                Button(extraTitle, action: extraAction)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .nightCard()
    }
}
