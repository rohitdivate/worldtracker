import Foundation

/// A single located instant from a Timeline export.
public struct TimelineSample: Sendable, Equatable {
    public let point: GeoPoint
    public let timestamp: Date
    /// UTC offset embedded in the source timestamp (on-device exports carry
    /// local offsets) — the day-bucketing fallback when the coordinate has no
    /// nearby city timezone.
    public let utcOffsetSeconds: Int?

    public init(point: GeoPoint, timestamp: Date, utcOffsetSeconds: Int? = nil) {
        self.point = point
        self.timestamp = timestamp
        self.utcOffsetSeconds = utcOffsetSeconds
    }
}

/// A stay at one location spanning an interval (visits / place visits).
public struct TimelineStay: Sendable, Equatable {
    public let point: GeoPoint
    public let start: Date
    public let end: Date
    public let utcOffsetSeconds: Int?

    public init(point: GeoPoint, start: Date, end: Date, utcOffsetSeconds: Int? = nil) {
        self.point = point
        self.start = start
        self.end = end
        self.utcOffsetSeconds = utcOffsetSeconds
    }
}

public enum TimelineFormat: Sendable, Equatable {
    /// Legacy Takeout Records.json — raw located instants, can be huge.
    case records
    /// Legacy Takeout Semantic Location History monthly file.
    case semanticMonthly
    /// Post-2024 on-device export from the Google Maps app.
    case onDeviceExport
}

public struct TimelineParseSummary: Sendable, Equatable {
    public var recordsRead = 0
    public var recordsSkipped = 0

    public init() {}
}
