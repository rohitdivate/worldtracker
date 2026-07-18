import Foundation

/// A photo reduced to the three fields the backfill needs.
public struct PhotoSample: Sendable, Equatable {
    public let id: String
    public let point: GeoPoint
    public let timestamp: Date

    public init(id: String, point: GeoPoint, timestamp: Date) {
        self.id = id
        self.point = point
        self.timestamp = timestamp
    }
}

/// A spatio-temporal cluster of photos — a candidate "place you spent time".
public struct PhotoCluster: Sendable, Equatable {
    public let center: GeoPoint
    public let start: Date
    public let end: Date
    public let assetIDs: [String]

    public init(center: GeoPoint, start: Date, end: Date, assetIDs: [String]) {
        self.center = center
        self.start = start
        self.end = end
        self.assetIDs = assetIDs
    }
}

public struct ClusterConfig: Sendable {
    /// New cluster when the time gap to the previous photo exceeds this.
    public var maxGapMinutes: Int
    /// New cluster when a photo is farther than this from the running center.
    public var maxRadiusMeters: Double
    /// Clusters below this size are dropped (kills GPS outliers and
    /// single mistagged shots).
    public var minCount: Int

    public init(maxGapMinutes: Int = 90, maxRadiusMeters: Double = 300, minCount: Int = 3) {
        self.maxGapMinutes = maxGapMinutes
        self.maxRadiusMeters = maxRadiusMeters
        self.minCount = minCount
    }
}

/// Greedy single-pass spatio-temporal clustering over time-sorted samples.
public func clusterPhotoSamples(_ samples: [PhotoSample], config: ClusterConfig = ClusterConfig()) -> [PhotoCluster] {
    guard !samples.isEmpty else { return [] }
    let sorted = samples.sorted { $0.timestamp < $1.timestamp }

    var clusters: [PhotoCluster] = []
    var currentIDs: [String] = []
    var sumLat = 0.0
    var sumLon = 0.0
    var start = sorted[0].timestamp
    var last = sorted[0].timestamp

    func center() -> GeoPoint {
        GeoPoint(
            latitude: sumLat / Double(currentIDs.count),
            longitude: sumLon / Double(currentIDs.count)
        )
    }

    func flush(end: Date) {
        if currentIDs.count >= config.minCount {
            clusters.append(
                PhotoCluster(center: center(), start: start, end: end, assetIDs: currentIDs)
            )
        }
        currentIDs = []
        sumLat = 0
        sumLon = 0
    }

    for sample in sorted {
        if currentIDs.isEmpty {
            currentIDs = [sample.id]
            sumLat = sample.point.latitude
            sumLon = sample.point.longitude
            start = sample.timestamp
            last = sample.timestamp
            continue
        }

        let gap = sample.timestamp.timeIntervalSince(last) / 60
        let distance = Haversine.meters(from: center(), to: sample.point)

        if gap > Double(config.maxGapMinutes) || distance > config.maxRadiusMeters {
            flush(end: last)
            currentIDs = [sample.id]
            sumLat = sample.point.latitude
            sumLon = sample.point.longitude
            start = sample.timestamp
        } else {
            currentIDs.append(sample.id)
            sumLat += sample.point.latitude
            sumLon += sample.point.longitude
        }
        last = sample.timestamp
    }
    flush(end: last)
    return clusters
}
