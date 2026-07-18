import SwiftUI
import WorldTrackerKit

/// The Time Machine: rebuild travel history from photo-library metadata.
struct PhotoSyncView: View {
    private var engine: PhotoBackfillEngine { AppContainer.shared.backfillEngine }
    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var progress: BackfillProgress { engine.progress }

    @State private var lastSync: (status: String, days: Int, photos: Int, at: Date)?

    var body: some View {
        ZStack {
            Theme.sky.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    if progress.isRunning {
                        TimeMachineProgressView(progress: progress)
                    } else {
                        header
                        if case .done(let days, let photos) = progress.stage {
                            doneCard(days: days, photos: photos)
                        } else if case .failed(let message) = progress.stage {
                            failedCard(message)
                        } else if let lastSync, lastSync.status == "done" {
                            lastSyncCard(lastSync)
                        }
                        gapOptions
                        startButton
                        privacyNote
                    }
                }
                .padding(18)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Time Machine")
        .task {
            lastSync = await engine.lastSync()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.auroraGradient)
            Text("Ten years of travel,\nreconstructed in a minute.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Been There reads only each photo's date and location — never the pictures themselves, and nothing is downloaded from iCloud. Borders are matched entirely on this device.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var gapOptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DAYS WITH NO PHOTOS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.ink3)
                .padding(.bottom, 6)

            gapOption(
                mode: "leaveEmpty",
                title: "Leave them empty",
                detail: "Only days with evidence are filled"
            )
            gapOption(
                mode: "assume",
                title: "Assume I stayed put",
                detail: "Carry the last known country forward until a photo shows you somewhere new"
            )
            gapOption(
                mode: "short",
                title: "Fill short gaps only",
                detail: "Fill gaps up to \(store.gapFillMaxDays) days; longer ones stay empty for review"
            )

            if store.gapFillModeRaw == "short" {
                Stepper(value: Binding(
                    get: { store.gapFillMaxDays },
                    set: { store.gapFillMaxDays = $0 }
                ), in: 1...14) {
                    Text("Up to \(store.gapFillMaxDays) days")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    private func gapOption(mode: String, title: String, detail: String) -> some View {
        Button {
            store.gapFillModeRaw = mode
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: store.gapFillModeRaw == mode ? "circle.inset.filled" : "circle")
                    .foregroundStyle(store.gapFillModeRaw == mode ? Theme.aurora1 : Theme.ink3)
                    .font(.system(size: 16))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            engine.run()
        } label: {
            Text(lastSync?.status == "done" ? "Re-sync from photos" : "Rebuild my history")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.sky)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func doneCard(days: Int, photos: Int) -> some View {
        VStack(spacing: 6) {
            Text("✨ Re-sync complete")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Reconstructed \(days) travel days from \(photos) photos. Your calendar and map are up to date.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .nightCard()
    }

    private func failedCard(_ message: String) -> some View {
        Label {
            Text(message).font(.system(size: 13)).foregroundStyle(Theme.ink2)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.alert)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    private func lastSyncCard(_ sync: (status: String, days: Int, photos: Int, at: Date)) -> some View {
        LabeledContent {
            Text(sync.at.formatted(.relative(presentation: .named)))
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
        } label: {
            Text("Last scan: \(sync.days) days from \(sync.photos) photos")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
        }
        .padding(14)
        .nightCard()
    }

    private var privacyNote: some View {
        Text("Re-running a scan replaces only photo-derived days. Manual edits and GPS-tracked days are always kept.")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
    }
}

/// The develop-animation progress screen — the app's wow moment.
struct TimeMachineProgressView: View {
    let progress: BackfillProgress

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Theme.card, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.02, progress.fraction))
                    .stroke(
                        Theme.auroraGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress.fraction)
                VStack(spacing: 2) {
                    Text("\(Int(progress.fraction * 100))%")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.auroraGradient)
                        .contentTransition(.numericText())
                    Text(stageLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.ink3)
                }
            }
            .frame(width: 170, height: 170)
            .padding(.top, 30)

            Text("**\(progress.processed.formatted())** of \(progress.total.formatted()) photos examined\n**\(progress.foundDays)** travel days · **\(progress.countriesFound.count)** countries found")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())

            // Found-flag stream: each new flag "develops" in.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(Array(progress.recentFlags.enumerated()), id: \.offset) { _, flag in
                    Text(flag)
                        .font(.system(size: 26))
                        .transition(.scale(scale: 1.7).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.5), value: progress.recentFlags)
            .frame(minHeight: 80)
            .padding(.horizontal, 8)

            Text("You can leave this screen — the scan continues.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .nightCard()
    }

    private var stageLabel: String {
        switch progress.stage {
        case .requestingAuth: return "PERMISSION"
        case .scanning: return "SCANNING"
        case .writing: return "WRITING"
        default: return "WORKING"
        }
    }
}

#Preview {
    NavigationStack { PhotoSyncView() }
        .preferredColorScheme(.dark)
}
