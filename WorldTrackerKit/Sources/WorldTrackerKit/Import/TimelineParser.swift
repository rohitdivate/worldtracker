import Foundation

/// Parsers for the three Google Timeline export shapes. Elements arrive from
/// JSONArrayStreamer one at a time, are decoded leniently with
/// JSONSerialization (Google's field spellings drift), and are emitted as
/// TimelineSample/TimelineStay callbacks so callers never hold a full file.
public struct TimelineParser {
    /// Sniff the first ~64 KB for the identifying array key.
    public static func detectFormat(head: Data) -> TimelineFormat? {
        let text = String(decoding: head.prefix(64 << 10), as: UTF8.self)
        if text.contains("\"semanticSegments\"") { return .onDeviceExport }
        if text.contains("\"timelineObjects\"") { return .semanticMonthly }
        if text.contains("\"locations\"") { return .records }
        return nil
    }

    public static func detectFormat(url: URL) -> TimelineFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let head = try? handle.read(upToCount: 64 << 10) else {
            return nil
        }
        try? handle.close()
        return detectFormat(head: head)
    }

    @discardableResult
    public static func parse(
        url: URL,
        format: TimelineFormat,
        minSampleInterval: TimeInterval = 600,
        onSample: (TimelineSample) -> Void,
        onStay: (TimelineStay) -> Void,
        onProgress: ((Double) -> Void)? = nil
    ) throws -> TimelineParseSummary {
        var summary = TimelineParseSummary()
        let streamer = JSONArrayStreamer()

        switch format {
        case .records:
            var lastKept: Date?
            try streamer.streamArray(at: url, key: "locations", element: { data in
                summary.recordsRead += 1
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let sample = recordsSample(obj) else {
                    summary.recordsSkipped += 1
                    return
                }
                if let last = lastKept {
                    let delta = sample.timestamp.timeIntervalSince(last)
                    // Drop only forward near-duplicates; out-of-order records
                    // (rare, but real files aren't guaranteed sorted) are kept.
                    if delta >= 0, delta < minSampleInterval {
                        return
                    }
                }
                lastKept = sample.timestamp
                onSample(sample)
            }, progress: onProgress)

        case .semanticMonthly:
            try streamer.streamArray(at: url, key: "timelineObjects", element: { data in
                summary.recordsRead += 1
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    summary.recordsSkipped += 1
                    return
                }
                if let visit = obj["placeVisit"] as? [String: Any],
                   let stay = semanticStay(visit) {
                    onStay(stay)
                } else if let segment = obj["activitySegment"] as? [String: Any] {
                    var emitted = false
                    if let sample = semanticEndpoint(segment, locationKey: "startLocation", timeKey: "startTimestamp") {
                        onSample(sample)
                        emitted = true
                    }
                    if let sample = semanticEndpoint(segment, locationKey: "endLocation", timeKey: "endTimestamp") {
                        onSample(sample)
                        emitted = true
                    }
                    if !emitted { summary.recordsSkipped += 1 }
                } else {
                    summary.recordsSkipped += 1
                }
            }, progress: onProgress)

        case .onDeviceExport:
            try streamer.streamArray(at: url, key: "semanticSegments", element: { data in
                summary.recordsRead += 1
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    summary.recordsSkipped += 1
                    return
                }
                if !onDeviceSegment(obj, onSample: onSample, onStay: onStay) {
                    summary.recordsSkipped += 1
                }
            }, progress: onProgress)
        }
        return summary
    }

    // MARK: - Records.json

    private static func recordsSample(_ obj: [String: Any]) -> TimelineSample? {
        guard var latE7 = int64(obj["latitudeE7"]), var lonE7 = int64(obj["longitudeE7"]) else {
            return nil
        }
        // Known Takeout corruption: values offset by 2^32.
        if latE7 > 900_000_000 { latE7 -= 4_294_967_296 }
        if lonE7 > 1_800_000_000 { lonE7 -= 4_294_967_296 }
        let lat = Double(latE7) / 1e7
        let lon = Double(lonE7) / 1e7
        guard abs(lat) <= 90, abs(lon) <= 180, !(lat == 0 && lon == 0) else { return nil }

        let date: Date?
        if let iso = obj["timestamp"] as? String {
            date = parseISO(iso)?.date
        } else if let ms = obj["timestampMs"] as? String, let value = Double(ms) {
            date = Date(timeIntervalSince1970: value / 1000)
        } else if let ms = obj["timestampMs"] as? Double {
            date = Date(timeIntervalSince1970: ms / 1000)
        } else {
            date = nil
        }
        guard let timestamp = date else { return nil }
        return TimelineSample(
            point: GeoPoint(latitude: lat, longitude: lon),
            timestamp: timestamp
        )
    }

    // MARK: - Semantic monthly

    private static func semanticStay(_ visit: [String: Any]) -> TimelineStay? {
        guard let location = visit["location"] as? [String: Any],
              let latE7 = int64(location["latitudeE7"]),
              let lonE7 = int64(location["longitudeE7"]),
              let duration = visit["duration"] as? [String: Any],
              let start = (duration["startTimestamp"] as? String).flatMap({ parseISO($0)?.date }),
              let end = (duration["endTimestamp"] as? String).flatMap({ parseISO($0)?.date })
        else { return nil }
        let lat = Double(latE7) / 1e7
        let lon = Double(lonE7) / 1e7
        guard abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return TimelineStay(
            point: GeoPoint(latitude: lat, longitude: lon),
            start: start,
            end: end
        )
    }

    private static func semanticEndpoint(
        _ segment: [String: Any], locationKey: String, timeKey: String
    ) -> TimelineSample? {
        guard let location = segment[locationKey] as? [String: Any],
              let latE7 = int64(location["latitudeE7"]),
              let lonE7 = int64(location["longitudeE7"]),
              let duration = segment["duration"] as? [String: Any],
              let timestamp = (duration[timeKey] as? String).flatMap({ parseISO($0)?.date })
        else { return nil }
        let lat = Double(latE7) / 1e7
        let lon = Double(lonE7) / 1e7
        guard abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return TimelineSample(point: GeoPoint(latitude: lat, longitude: lon), timestamp: timestamp)
    }

    // MARK: - On-device export

    /// Returns false when the segment held nothing usable.
    private static func onDeviceSegment(
        _ obj: [String: Any],
        onSample: (TimelineSample) -> Void,
        onStay: (TimelineStay) -> Void
    ) -> Bool {
        let startParsed = (obj["startTime"] as? String).flatMap(parseISO)
        let endParsed = (obj["endTime"] as? String).flatMap(parseISO)

        if let visit = obj["visit"] as? [String: Any] {
            guard let top = visit["topCandidate"] as? [String: Any],
                  let point = latLngPoint(in: top["placeLocation"]),
                  let start = startParsed, let end = endParsed else {
                return false
            }
            onStay(TimelineStay(
                point: point,
                start: start.date,
                end: end.date,
                utcOffsetSeconds: start.offsetSeconds
            ))
            return true
        }

        if let path = obj["timelinePath"] as? [[String: Any]], let start = startParsed {
            var emitted = false
            for entry in path {
                guard let point = latLngPoint(in: entry["point"] ?? entry) else { continue }
                let minutes = doubleValue(entry["durationMinutesOffsetFromStartTime"]) ?? 0
                onSample(TimelineSample(
                    point: point,
                    timestamp: start.date.addingTimeInterval(minutes * 60),
                    utcOffsetSeconds: start.offsetSeconds
                ))
                emitted = true
            }
            return emitted
        }

        if let activity = obj["activity"] as? [String: Any] {
            var emitted = false
            if let point = latLngPoint(in: activity["start"]), let start = startParsed {
                onSample(TimelineSample(point: point, timestamp: start.date, utcOffsetSeconds: start.offsetSeconds))
                emitted = true
            }
            if let point = latLngPoint(in: activity["end"]), let end = endParsed {
                onSample(TimelineSample(point: point, timestamp: end.date, utcOffsetSeconds: end.offsetSeconds))
                emitted = true
            }
            return emitted
        }

        // userLocationProfile / unknown segment kinds.
        return false
    }

    // MARK: - Shared helpers

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? Int64 { return number }
        if let number = value as? Int { return Int64(number) }
        if let number = value as? Double { return Int64(number) }
        if let number = value as? NSNumber { return number.int64Value }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let text = value as? String { return Double(text) }
        return nil
    }

    /// "48.8575°, 2.3514°" (or a container {"latLng": "..."}), degree signs
    /// and spacing tolerated.
    static func latLngPoint(in value: Any?) -> GeoPoint? {
        var text: String?
        if let string = value as? String {
            text = string
        } else if let dict = value as? [String: Any] {
            text = dict["latLng"] as? String ?? dict["LatLng"] as? String
        }
        guard let raw = text else { return nil }
        let cleaned = raw.replacingOccurrences(of: "°", with: "")
        let parts = cleaned.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 2,
              let lat = Double(parts[0]), let lon = Double(parts[1]),
              abs(lat) <= 90, abs(lon) <= 180 else {
            return nil
        }
        return GeoPoint(latitude: lat, longitude: lon)
    }

    /// ISO8601 with/without fractional seconds; returns the embedded UTC
    /// offset so day bucketing can fall back to the recorded local time.
    static func parseISO(_ value: String) -> (date: Date, offsetSeconds: Int?)? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        guard let date = withFraction.date(from: value) ?? plain.date(from: value) else {
            return nil
        }
        return (date, extractOffsetSeconds(value))
    }

    private static func extractOffsetSeconds(_ value: String) -> Int? {
        if value.hasSuffix("Z") { return 0 }
        // Scan from the end for ±HH:MM (after the time part).
        guard let signIndex = value.lastIndex(where: { $0 == "+" || $0 == "-" }),
              signIndex > value.index(value.startIndex, offsetBy: 10) else {
            return nil
        }
        let suffix = value[value.index(after: signIndex)...]
        let parts = suffix.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else {
            return nil
        }
        let magnitude = hours * 3600 + minutes * 60
        return value[signIndex] == "-" ? -magnitude : magnitude
    }
}
