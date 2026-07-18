import SwiftUI
import WorldTrackerKit

/// Developer screen: proves the offline atlas works on-device.
/// Try it in airplane mode — every lookup is local.
struct DeveloperGeoView: View {
    private struct Sample: Identifiable {
        let id = UUID()
        let label: String
        let point: GeoPoint
    }

    private static let samples: [Sample] = [
        .init(label: "London", point: GeoPoint(latitude: 51.5074, longitude: -0.1278)),
        .init(label: "Paris", point: GeoPoint(latitude: 48.8566, longitude: 2.3522)),
        .init(label: "Barcelona", point: GeoPoint(latitude: 41.3874, longitude: 2.1686)),
        .init(label: "Marrakech", point: GeoPoint(latitude: 31.6295, longitude: -7.9811)),
        .init(label: "Tokyo", point: GeoPoint(latitude: 35.6762, longitude: 139.6503)),
        .init(label: "Mid-Atlantic", point: GeoPoint(latitude: 30, longitude: -40)),
    ]

    @State private var lookup: GeoLookup?
    @State private var loadError: String?
    @State private var customLat = ""
    @State private var customLon = ""
    @State private var customResult: String?

    var body: some View {
        List {
            Section("Offline atlas") {
                if let error = loadError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.alert)
                } else if lookup == nil {
                    HStack {
                        ProgressView()
                        Text("Loading atlas…").foregroundStyle(Theme.ink2)
                    }
                }
                if let lookup {
                    LabeledContent("Countries", value: "\(lookup.countries.numberOfCountries)")
                }
            }

            if let lookup {
                Section("Canned lookups (works in airplane mode)") {
                    ForEach(Self.samples) { sample in
                        row(sample: sample, lookup: lookup)
                    }
                }

                Section("Custom coordinate") {
                    TextField("Latitude", text: $customLat)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $customLon)
                        .keyboardType(.numbersAndPunctuation)
                    Button("Resolve") {
                        guard let lat = Double(customLat), let lon = Double(customLon) else {
                            customResult = "Enter numeric lat/lon"
                            return
                        }
                        customResult = describe(
                            lookup.resolve(GeoPoint(latitude: lat, longitude: lon))
                        )
                    }
                    if let customResult {
                        Text(customResult)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }
        }
        .navigationTitle("Geo lookup")
        .scrollContentBackground(.hidden)
        .background(Theme.sky)
        .task {
            guard lookup == nil else { return }
            do {
                lookup = try await Task.detached { try GeoLookup() }.value
            } catch {
                loadError = "Atlas failed to load: \(error)"
            }
        }
    }

    private func row(sample: Sample, lookup: GeoLookup) -> some View {
        let res = lookup.resolve(sample.point)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(res.countryCode.map(flagEmoji) ?? "🌊")
                Text(sample.label).fontWeight(.semibold)
                Spacer()
                Text(res.countryCode ?? "none")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(res.countryCode == nil ? Theme.ink3 : Theme.aurora1)
            }
            Text(describe(res))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.ink3)
        }
    }

    private func describe(_ res: GeoResolution) -> String {
        let city = res.cityName ?? "-"
        let admin = res.admin1 ?? "-"
        let tz = res.timeZoneID ?? "-"
        let fb = res.usedNearestLandFallback ? " (nearest-land)" : ""
        return "\(city), \(admin) · \(tz)\(fb)"
    }
}

#Preview {
    NavigationStack { DeveloperGeoView() }
        .preferredColorScheme(.dark)
}
