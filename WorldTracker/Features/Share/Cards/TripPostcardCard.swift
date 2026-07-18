import SwiftUI
import UIKit
import WorldTrackerKit

/// One trip as a postcard: flag, dates, cities, and up to three photos —
/// pre-awaited UIImages only, so the renderer never touches Photos.
struct TripPostcardCard: View {
    let countryCode: String
    let dateRange: String
    let dayCount: Int
    let cities: [String]
    let photos: [UIImage]

    var body: some View {
        ZStack {
            StaticAurora()

            VStack(spacing: 10) {
                Spacer().frame(height: 30)

                FlagChip(code: countryCode, size: 64)
                    .shadow(color: Theme.aurora1.opacity(0.4), radius: 16)

                Text(countryName(countryCode))
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("\(dateRange) · \(dayCount) \(dayCount == 1 ? "day" : "days")")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.ink2)

                if !cities.isEmpty {
                    Text(cities.prefix(3).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                        .padding(.horizontal, 24)
                }

                if !photos.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(photos.prefix(3).enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 98, height: 98)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()

                ShareWordmark(withHook: true)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 360, height: 450)
    }
}
