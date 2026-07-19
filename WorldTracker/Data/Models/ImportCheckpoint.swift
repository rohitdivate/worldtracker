import Foundation
import SwiftData

/// Local-only record of the last bulk import per origin (timeline/flight).
/// Powers the "last import" summaries and the remove-imported-data flow.
@Model
final class ImportCheckpoint {
    /// FactSource raw value: "importTimeline" | "importFlight"
    var originRaw: String = ""
    var fileNames: String = ""
    var importedAt: Date = Date()
    var dayCount: Int = 0
    var recordCount: Int = 0
    var countryCount: Int = 0
    var skippedCount: Int = 0
    /// "done" | "failed"
    var statusRaw: String = "done"

    init(originRaw: String) {
        self.originRaw = originRaw
        self.importedAt = Date()
    }
}
