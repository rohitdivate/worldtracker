import SwiftUI
import UniformTypeIdentifiers
import WorldTrackerKit

/// Shared progress UI for bulk imports (ring + counters + flag stream).
struct ImportProgressView: View {
    let progress: ImportProgress
    let subjectLabel: String  // "records" / "flights"

    var body: some View {
        VStack(spacing: 18) {
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
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.auroraGradient)
                        .contentTransition(.numericText())
                    Text(progress.stage == .writing ? "WRITING" : "READING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.ink3)
                }
            }
            .frame(width: 150, height: 150)
            .padding(.top, 20)

            Text("**\(progress.foundDays)** travel days · **\(progress.countriesFound.count)** countries found")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .contentTransition(.numericText())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(Array(progress.recentFlags.enumerated()), id: \.offset) { _, flag in
                    Text(flag)
                        .font(.system(size: 24))
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.5), value: progress.recentFlags)
            .frame(minHeight: 60)

            Text("You can leave this screen — the import continues.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .nightCard()
    }
}

/// Import Google Timeline exports.
struct ImportTimelineView: View {
    @State private var showPicker = false
    @State private var confirmRemove = false
    @State private var lastImport: CheckpointSnapshot?

    private var engine: ImportEngine { AppContainer.shared.importEngine }
    private var progress: ImportProgress { engine.timelineProgress }

    var body: some View {
        ZStack {
            Theme.sky.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if progress.isRunning {
                        ImportProgressView(progress: progress, subjectLabel: "records")
                    } else {
                        header
                        stageCards
                        pickButton
                        if lastImport != nil {
                            removeButton
                        }
                        privacyNote
                    }
                }
                .padding(18)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Google Timeline")
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                engine.runTimelineImport(urls: urls)
            }
        }
        .confirmationDialog(
            "Remove imported Timeline data?",
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("Remove Timeline data", role: .destructive) {
                engine.removeImported(origin: .timeline)
                lastImport = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only Timeline-imported days are removed. Everything else stays.")
        }
        .task { lastImport = await engine.lastCheckpoint(origin: .timeline) }
        .onChange(of: progress.stage) { _, stage in
            if case .done = stage {
                Task { lastImport = await engine.lastCheckpoint(origin: .timeline) }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "map.fill")
                .font(.system(size: 38))
                .foregroundStyle(Theme.auroraGradient)
            Text("Years of history,\nfrom Google Timeline.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("If you've used Google Maps for years, your Timeline remembers your travels. Export it and Been There will rebuild everything — parsed entirely on this device.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var stageCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW TO GET YOUR EXPORT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.ink3)
            step(1, "Open the Google Maps app and tap your profile picture")
            step(2, "Your Timeline → ⋯ → Location & privacy settings")
            step(3, "\"Export Timeline data\" — save the JSON to Files")
            step(4, "Pick that file below (old Takeout files work too)")

            if case .done(let days, let records, let countries, let skipped, _) = progress.stage {
                doneCard(days: days, records: records, countries: countries, skipped: skipped)
            } else if case .failed(let message) = progress.stage {
                failCard(message)
            } else if let lastImport {
                Text("Last import: \(lastImport.dayCount) days across \(lastImport.countryCount) countries · \(lastImport.importedAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    private var pickButton: some View {
        Button {
            showPicker = true
        } label: {
            Text(lastImport == nil ? "Choose Timeline file" : "Re-import Timeline file")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.sky)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var removeButton: some View {
        Button {
            confirmRemove = true
        } label: {
            Text("Remove imported Timeline data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
    }

    private var privacyNote: some View {
        Text("Re-importing replaces only Timeline-derived days. Manual edits, GPS tracking and photo history are always kept. The file is deleted after import.")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}

/// Import flight history CSVs.
struct ImportFlightsView: View {
    @State private var showPicker = false
    @State private var confirmRemove = false
    @State private var lastImport: CheckpointSnapshot?

    private var engine: ImportEngine { AppContainer.shared.importEngine }
    private var progress: ImportProgress { engine.flightProgress }

    var body: some View {
        ZStack {
            Theme.sky.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if progress.isRunning {
                        ImportProgressView(progress: progress, subjectLabel: "flights")
                    } else {
                        header
                        infoCard
                        pickButton
                        if lastImport != nil {
                            removeButton
                        }
                        note
                    }
                }
                .padding(18)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Flights")
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                engine.runFlightImport(urls: urls)
            }
        }
        .confirmationDialog(
            "Remove imported flight data?",
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("Remove flight data", role: .destructive) {
                engine.removeImported(origin: .flight)
                lastImport = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only flight-imported days are removed. Everything else stays.")
        }
        .task { lastImport = await engine.lastCheckpoint(origin: .flight) }
        .onChange(of: progress.stage) { _, stage in
            if case .done = stage {
                Task { lastImport = await engine.lastCheckpoint(origin: .flight) }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(Theme.auroraGradient)
            Text("Every flight,\non the record.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Flights close the gaps your phone can't see (airplane mode). A flight credits the departure day in the origin country and the arrival day where you landed — timezone-correct for overnight routes.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUPPORTED FILES")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.ink3)
            step(1, "Flighty: Settings → Export My Data → CSV")
            step(2, "Or any CSV with date,origin,destination rows (IATA codes, e.g. 2026-03-29,LHR,BCN)")

            if case .done(let days, let flights, let countries, let skipped, let unknown) = progress.stage {
                doneCard(days: days, records: flights, countries: countries, skipped: skipped)
                if !unknown.isEmpty {
                    Text("Airports not recognized: \(unknown.joined(separator: ", "))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.amber)
                }
            } else if case .failed(let message) = progress.stage {
                failCard(message)
            } else if let lastImport {
                Text("Last import: \(lastImport.recordCount) flights → \(lastImport.dayCount) days · \(lastImport.importedAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightCard()
    }

    private var pickButton: some View {
        Button {
            showPicker = true
        } label: {
            Text(lastImport == nil ? "Choose flight CSV" : "Re-import flight CSV")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.sky)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var removeButton: some View {
        Button {
            confirmRemove = true
        } label: {
            Text("Remove imported flight data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
    }

    private var note: some View {
        Text("Re-importing replaces only flight-derived days. Canceled flights are skipped; diversions credit where you actually landed.")
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}

// MARK: - Small shared pieces

private func step(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Text("\(number)")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(Theme.sky)
            .frame(width: 18, height: 18)
            .background(Theme.auroraGradient, in: Circle())
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink2)
        Spacer()
    }
}

private func doneCard(days: Int, records: Int, countries: Int, skipped: Int) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("✨ Import complete")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.ink)
        Text("Added \(days) travel days across \(countries) countries from \(records.formatted()) records.\(skipped > 0 ? " Skipped \(skipped) unusable records." : "")")
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.ink2)
    }
    .padding(.top, 6)
}

private func failCard(_ message: String) -> some View {
    Label {
        Text(message).font(.system(size: 12.5)).foregroundStyle(Theme.ink2)
    } icon: {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.alert)
    }
    .padding(.top, 6)
}

#Preview {
    NavigationStack { ImportTimelineView() }
        .preferredColorScheme(.dark)
}
