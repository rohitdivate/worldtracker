import SwiftUI
import WorldTrackerKit

/// Dedicated share compositions — designed layouts, not screenshots.
/// WrappedShareRenderer rasterizes them at 3×: the story card becomes
/// 1080×1920, the square card 1080×1080.

/// One deterministic aurora frame — ImageRenderer never sees a TimelineView.
private struct StaticAurora: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.38, 0.32], [1, 0.5],
                [0, 1], [0.7, 0.6], [1, 1],
            ],
            colors: [
                Theme.sky, Theme.skyRaised, Theme.sky,
                Theme.skyRaised,
                Theme.aurora1.opacity(0.30),
                Theme.aurora2.opacity(0.28),
                Theme.sky, Theme.skyRaised, Theme.sky,
            ]
        )
    }
}

private struct ShareWordmark: View {
    var body: some View {
        HStack(spacing: 7) {
            MiniGlobe(size: 16, showsPlane: false)
            Text("BEEN THERE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.ink2)
        }
    }
}

private struct ShareStat: View {
    let value: String
    let label: String
    var color: Color = Theme.aurora1

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Story (9:16)

struct WrappedStoryCard: View {
    let data: YearInReviewBuilder.WrappedData

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                Text("MY YEAR IN TRAVEL")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(Theme.aurora1)
                Text(String(data.stats.year))
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.auroraGradient)
                    .padding(.top, 2)

                WrappedMapCanvas(
                    shapes: data.shapes,
                    daysPerCountry: data.daysPerCountry,
                    homeCountry: data.stats.homeCountry,
                    homeCentroid: data.homeCentroid,
                    arcTargets: data.arcTargets,
                    lightOrder: data.stats.firstAppearanceOrder
                )
                .frame(width: 336, height: 168)
                .padding(.top, 18)

                HStack(spacing: 0) {
                    ShareStat(value: "\(data.stats.countriesVisited)", label: "COUNTRIES")
                    ShareStat(value: "\(data.stats.travelDays)", label: "TRAVEL DAYS")
                    ShareStat(value: "\(data.stats.borderCrossings)", label: "CROSSINGS")
                    if !data.stats.firstVisits.isEmpty {
                        ShareStat(value: "+\(data.stats.firstVisits.count)", label: "NEW",
                                  color: Theme.amber)
                    }
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.card.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Theme.hairline2, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if let trip = data.stats.longestTrip {
                    Text("Longest trip · \(trip.dayCount) days · \(trip.countryCodes.map(flagEmoji).joined(separator: " "))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .padding(.top, 14)
                }

                flagRow
                    .padding(.top, 14)

                Spacer()

                ShareWordmark()
                    .padding(.bottom, 34)
            }
        }
        .frame(width: 360, height: 640)
    }

    private var flagRow: some View {
        HStack(spacing: 6) {
            ForEach(data.stats.firstAppearanceOrder.prefix(10), id: \.self) { code in
                Text(flagEmoji(code)).font(.system(size: 20))
            }
            if data.stats.firstAppearanceOrder.count > 10 {
                Text("+\(data.stats.firstAppearanceOrder.count - 10)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }
}

// MARK: - Square (1:1)

struct WrappedSquareCard: View {
    let data: YearInReviewBuilder.WrappedData

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 0) {
                Spacer().frame(height: 26)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(data.stats.year))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.auroraGradient)
                    Text("IN TRAVEL")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Theme.aurora1)
                }

                WrappedMapCanvas(
                    shapes: data.shapes,
                    daysPerCountry: data.daysPerCountry,
                    homeCountry: data.stats.homeCountry,
                    homeCentroid: data.homeCentroid,
                    arcTargets: data.arcTargets,
                    lightOrder: data.stats.firstAppearanceOrder
                )
                .frame(width: 320, height: 150)
                .padding(.top, 10)

                HStack(spacing: 0) {
                    ShareStat(value: "\(data.stats.countriesVisited)", label: "COUNTRIES")
                    ShareStat(value: "\(data.stats.travelDays)", label: "TRAVEL DAYS")
                    if !data.stats.firstVisits.isEmpty {
                        ShareStat(value: "+\(data.stats.firstVisits.count)", label: "NEW",
                                  color: Theme.amber)
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 30)

                Spacer()

                ShareWordmark()
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 360, height: 360)
    }
}

// MARK: - Renderer

/// ImageRenderer at 3× → PNG files ready for ShareLink.
@MainActor
enum WrappedShareRenderer {
    static func renderCards(for data: YearInReviewBuilder.WrappedData) -> [URL] {
        let year = data.stats.year
        return [
            render(WrappedStoryCard(data: data), name: "BeenThere-\(year)-story"),
            render(WrappedSquareCard(data: data), name: "BeenThere-\(year)"),
        ].compactMap { $0 }
    }

    private static func render(_ view: some View, name: String) -> URL? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.uiImage, let png = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).png")
        try? FileManager.default.removeItem(at: url)
        do {
            try png.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

#Preview("Story") {
    WrappedStoryCard(data: .previewSample)
}

#Preview("Square") {
    WrappedSquareCard(data: .previewSample)
}

extension YearInReviewBuilder.WrappedData {
    /// Fixture for canvas previews only.
    static var previewSample: YearInReviewBuilder.WrappedData {
        let jan1 = EpochDay.daysFromCivil(year: 2026, month: 1, day: 1)
        let stats = YearInReview.compute(
            year: 2026,
            days: (0..<120).map { offset in
                let code = switch offset {
                case 20..<29: "ES"
                case 60..<74: "JP"
                case 100..<103: "DK"
                default: "GB"
                }
                return ResolvedDay(day: jan1 + offset, countryCodes: [code], source: .gps, isFilled: false)
            },
            homeCountry: "GB",
            priorCountryCodes: ["GB", "ES"]
        )
        let shapes = try? WorldMapShapes()
        return .init(
            stats: stats,
            isPartialYear: false,
            homeCentroid: shapes?.centroid(forCountry: "GB"),
            arcTargets: ["ES", "JP", "DK"].compactMap { code in
                shapes?.centroid(forCountry: code).map { (code, $0) }
            },
            photoMoments: [],
            thumbnails: [:],
            shapes: shapes,
            daysPerCountry: ["GB": 94, "ES": 9, "JP": 14, "DK": 3],
            travelDayFlags: (0..<120).map { (20..<29).contains($0) || (60..<74).contains($0) || (100..<103).contains($0) }
        )
    }
}
