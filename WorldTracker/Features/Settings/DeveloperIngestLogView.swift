import SwiftUI
import WorldTrackerKit

/// Developer screen: raw view of recent location samples.
struct DeveloperIngestLogView: View {
    @State private var samples: [SampleSnapshot] = []

    var body: some View {
        List {
            if samples.isEmpty {
                Text("No samples yet. Grant location access and move around — significant-change events arrive at cell-tower granularity.")
                    .foregroundStyle(Theme.ink3)
                    .font(.footnote)
            }
            ForEach(samples) { sample in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(sample.countryCode.map(flagEmoji) ?? "❓")
                        Text(sample.city ?? "Unknown")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(sample.kindRaw)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.card, in: Capsule())
                            .foregroundStyle(Theme.aurora1)
                    }
                    Text("\(sample.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(String(format: "%.4f, %.4f", sample.latitude, sample.longitude))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .navigationTitle("Ingest log")
        .scrollContentBackground(.hidden)
        .background(Theme.sky)
        .task {
            samples = await AppContainer.shared.ingestor.recentSamples(limit: 200)
        }
        .refreshable {
            samples = await AppContainer.shared.ingestor.recentSamples(limit: 200)
        }
    }
}
