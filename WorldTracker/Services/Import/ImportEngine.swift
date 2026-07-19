import Foundation
import Observation
import SwiftData
import WorldTrackerKit

enum ImportOrigin: String, CaseIterable {
    case timeline = "importTimeline"
    case flight = "importFlight"

    var factSource: FactSource {
        self == .timeline ? .importedTimeline : .importedFlight
    }

    var confidence: Double {
        self == .timeline ? 0.85 : 0.75
    }
}

/// Observable progress for the import screens (Time Machine pattern).
@MainActor
@Observable
final class ImportProgress {
    enum Stage: Equatable {
        case idle
        case reading
        case writing
        case done(days: Int, records: Int, countries: Int, skipped: Int, unknownIATAs: [String])
        case failed(String)
    }

    var stage: Stage = .idle
    var fraction: Double = 0
    var recordsRead = 0
    var foundDays = 0
    var countriesFound: Set<String> = []
    var recentFlags: [String] = []

    var isRunning: Bool {
        switch stage {
        case .reading, .writing: return true
        default: return false
        }
    }
}

/// Database writer for bulk imports. Contract mirrors the photo Time
/// Machine: each import replaces ONLY its own origin's rows; manual, GPS
/// and photo history are never touched.
@ModelActor
actor ImportWriter {
    func clearImported(originRaw: String) {
        try? modelContext.delete(
            model: CountryDayFact.self,
            where: #Predicate { $0.sourceRaw == originRaw }
        )
        try? modelContext.save()
    }

    func write(facts: [ImportDayFact], originRaw: String, confidence: Double) -> Int {
        for fact in facts {
            let row = CountryDayFact(
                epochDay: fact.day,
                countryCode: fact.countryCode,
                sourceRaw: originRaw,
                confidence: confidence,
                seenAt: fact.first
            )
            row.evidenceCount = fact.evidenceCount
            row.lastSeenAt = fact.last
            modelContext.insert(row)
        }
        try? modelContext.save()
        return Set(facts.map(\.day)).count
    }

    func recordCheckpoint(
        originRaw: String,
        fileNames: [String],
        days: Int,
        records: Int,
        countries: Int,
        skipped: Int,
        status: String
    ) {
        let predicate = #Predicate<ImportCheckpoint> { $0.originRaw == originRaw }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let checkpoint = (try? modelContext.fetch(descriptor))?.first ?? {
            let fresh = ImportCheckpoint(originRaw: originRaw)
            modelContext.insert(fresh)
            return fresh
        }()
        checkpoint.fileNames = fileNames.joined(separator: ", ")
        checkpoint.importedAt = Date()
        checkpoint.dayCount = days
        checkpoint.recordCount = records
        checkpoint.countryCount = countries
        checkpoint.skippedCount = skipped
        checkpoint.statusRaw = status
        try? modelContext.save()
    }

    func removeCheckpoint(originRaw: String) {
        let predicate = #Predicate<ImportCheckpoint> { $0.originRaw == originRaw }
        for checkpoint in (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? [] {
            modelContext.delete(checkpoint)
        }
        try? modelContext.save()
    }

    func lastCheckpoint(originRaw: String) -> CheckpointSnapshot? {
        let predicate = #Predicate<ImportCheckpoint> { $0.originRaw == originRaw }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let checkpoint = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return CheckpointSnapshot(
            importedAt: checkpoint.importedAt,
            dayCount: checkpoint.dayCount,
            recordCount: checkpoint.recordCount,
            countryCount: checkpoint.countryCount,
            statusRaw: checkpoint.statusRaw
        )
    }
}

struct CheckpointSnapshot: Sendable {
    let importedAt: Date
    let dayCount: Int
    let recordCount: Int
    let countryCount: Int
    let statusRaw: String
}

/// Orchestrates file access, parsing (Kit), and writing for both import
/// origins. One shared instance in AppContainer.
final class ImportEngine {
    private let writer: ImportWriter
    private let geoProvider: GeoLookupProvider
    let timelineProgress: ImportProgress
    let flightProgress: ImportProgress

    @MainActor
    init(container: ModelContainer, geoProvider: GeoLookupProvider) {
        self.writer = ImportWriter(modelContainer: container)
        self.geoProvider = geoProvider
        self.timelineProgress = ImportProgress()
        self.flightProgress = ImportProgress()
    }

    // MARK: - Public entry points

    @MainActor
    func runTimelineImport(urls: [URL]) {
        guard !timelineProgress.isRunning, !urls.isEmpty else { return }
        reset(timelineProgress)
        let copies = secureCopies(of: urls)
        guard !copies.isEmpty else {
            timelineProgress.stage = .failed("Couldn't read the selected file. Try saving it to Files first.")
            return
        }
        Task.detached(priority: .userInitiated) { [self] in
            await executeTimeline(files: copies)
        }
    }

    @MainActor
    func runFlightImport(urls: [URL]) {
        guard !flightProgress.isRunning, !urls.isEmpty else { return }
        reset(flightProgress)
        let copies = secureCopies(of: urls)
        guard !copies.isEmpty else {
            flightProgress.stage = .failed("Couldn't read the selected file. Try saving it to Files first.")
            return
        }
        Task.detached(priority: .userInitiated) { [self] in
            await executeFlights(files: copies)
        }
    }

    @MainActor
    func removeImported(origin: ImportOrigin) {
        Task {
            await writer.clearImported(originRaw: origin.rawValue)
            await writer.removeCheckpoint(originRaw: origin.rawValue)
            await MainActor.run {
                progress(for: origin).stage = .idle
                NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
            }
        }
    }

    func lastCheckpoint(origin: ImportOrigin) async -> CheckpointSnapshot? {
        await writer.lastCheckpoint(originRaw: origin.rawValue)
    }

    @MainActor
    func progress(for origin: ImportOrigin) -> ImportProgress {
        origin == .timeline ? timelineProgress : flightProgress
    }

    // MARK: - Timeline

    private func executeTimeline(files: [(url: URL, name: String)]) async {
        defer { cleanup(files) }
        guard let lookup = try? await geoProvider.lookup() else {
            await fail(timelineProgress, "The offline atlas failed to load.")
            return
        }

        var aggregator = TimelineDayAggregator(lookup: lookup)
        var totalRead = 0
        var totalSkipped = 0
        let fileCount = Double(files.count)

        for (index, file) in files.enumerated() {
            guard let format = TimelineParser.detectFormat(url: file.url) else {
                await fail(
                    timelineProgress,
                    "\(file.name) isn't a recognized Google Timeline export. Supported: the Google Maps Timeline export, Takeout Records.json, and Semantic Location History monthly files."
                )
                return
            }
            let base = Double(index) / fileCount
            do {
                var sinceUpdate = 0
                let summary = try TimelineParser.parse(
                    url: file.url,
                    format: format,
                    onSample: { sample in
                        aggregator.add(sample)
                        sinceUpdate += 1
                        if sinceUpdate >= 500 {
                            sinceUpdate = 0
                            self.publishTimelineProgress(aggregator: aggregator, read: totalRead)
                        }
                    },
                    onStay: { stay in
                        aggregator.add(stay)
                    },
                    onProgress: { fileFraction in
                        let overall = base + fileFraction / fileCount
                        Task { @MainActor [self] in
                            timelineProgress.fraction = min(0.95, overall)
                        }
                    }
                )
                totalRead += summary.recordsRead
                totalSkipped += summary.recordsSkipped
            } catch {
                await fail(timelineProgress, "Couldn't parse \(file.name): \(error.localizedDescription)")
                return
            }
        }

        let (facts, countries, skippedNoCountry) = aggregator.finish()
        await MainActor.run { timelineProgress.stage = .writing }

        await writer.clearImported(originRaw: ImportOrigin.timeline.rawValue)
        let days = await writer.write(
            facts: facts,
            originRaw: ImportOrigin.timeline.rawValue,
            confidence: ImportOrigin.timeline.confidence
        )
        await writer.recordCheckpoint(
            originRaw: ImportOrigin.timeline.rawValue,
            fileNames: files.map(\.name),
            days: days,
            records: totalRead,
            countries: countries.count,
            skipped: totalSkipped + skippedNoCountry,
            status: "done"
        )

        await MainActor.run {
            timelineProgress.fraction = 1
            timelineProgress.foundDays = days
            timelineProgress.countriesFound = countries
            timelineProgress.stage = .done(
                days: days,
                records: totalRead,
                countries: countries.count,
                skipped: totalSkipped + skippedNoCountry,
                unknownIATAs: []
            )
            NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
        }
    }

    private func publishTimelineProgress(aggregator: TimelineDayAggregator, read: Int) {
        let (facts, countries, _) = aggregator.finish()
        let flags = countries.map(flagEmoji)
        Task { @MainActor [self] in
            timelineProgress.recordsRead = read
            timelineProgress.foundDays = Set(facts.map(\.day)).count
            timelineProgress.countriesFound = countries
            timelineProgress.recentFlags = Array(flags.prefix(18))
        }
    }

    // MARK: - Flights

    private func executeFlights(files: [(url: URL, name: String)]) async {
        defer { cleanup(files) }
        guard let lookup = try? await geoProvider.lookup(),
              let airports = try? AirportIndex() else {
            await fail(flightProgress, "The airport database failed to load.")
            return
        }

        var allFlights: [FlightRecord] = []
        var skippedRows = 0
        for file in files {
            guard let data = try? Data(contentsOf: file.url) else {
                await fail(flightProgress, "Couldn't read \(file.name).")
                return
            }
            do {
                let (flights, skipped) = try FlightCSVParser.parse(data: data)
                allFlights.append(contentsOf: flights)
                skippedRows += skipped
            } catch {
                await fail(
                    flightProgress,
                    "\(file.name) isn't a recognized flight CSV. Supported: a Flighty export, or a simple date,origin,destination file."
                )
                return
            }
        }

        let (facts, unknownIATAs, used) = flightDayFacts(
            flights: allFlights, airports: airports, lookup: lookup
        )
        await MainActor.run { flightProgress.stage = .writing }

        await writer.clearImported(originRaw: ImportOrigin.flight.rawValue)
        let days = await writer.write(
            facts: facts,
            originRaw: ImportOrigin.flight.rawValue,
            confidence: ImportOrigin.flight.confidence
        )
        let countries = Set(facts.map(\.countryCode))
        await writer.recordCheckpoint(
            originRaw: ImportOrigin.flight.rawValue,
            fileNames: files.map(\.name),
            days: days,
            records: used,
            countries: countries.count,
            skipped: skippedRows,
            status: "done"
        )

        await MainActor.run {
            flightProgress.fraction = 1
            flightProgress.foundDays = days
            flightProgress.countriesFound = countries
            flightProgress.recentFlags = countries.map(flagEmoji)
            flightProgress.stage = .done(
                days: days,
                records: used,
                countries: countries.count,
                skipped: skippedRows,
                unknownIATAs: unknownIATAs.sorted()
            )
            NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
        }
    }

    // MARK: - Shared

    @MainActor
    private func reset(_ progress: ImportProgress) {
        progress.stage = .reading
        progress.fraction = 0
        progress.recordsRead = 0
        progress.foundDays = 0
        progress.countriesFound = []
        progress.recentFlags = []
    }

    private func fail(_ progress: ImportProgress, _ message: String) async {
        await MainActor.run { progress.stage = .failed(message) }
    }

    /// Security-scoped Files URLs go stale quickly; copy to tmp immediately.
    @MainActor
    private func secureCopies(of urls: [URL]) -> [(url: URL, name: String)] {
        var copies: [(URL, String)] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("import-\(UUID().uuidString)-\(url.lastPathComponent)")
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                copies.append((destination, url.lastPathComponent))
            } catch {
                continue
            }
        }
        return copies
    }

    private func cleanup(_ files: [(url: URL, name: String)]) {
        for file in files {
            try? FileManager.default.removeItem(at: file.url)
        }
    }
}
