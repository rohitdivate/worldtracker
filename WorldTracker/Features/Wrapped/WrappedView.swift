import SwiftUI
import WorldTrackerKit

/// fullScreenCover(item:) wrapper — id is the year.
struct WrappedPresentation: Identifiable {
    let id: Int
    let data: YearInReviewBuilder.WrappedData
}

/// Full-screen story container: segment progress bars, tap left/right to
/// navigate, long-press to pause, drag down to dismiss, auto-advance.
struct WrappedView: View {
    let data: YearInReviewBuilder.WrappedData

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private enum Page: Hashable {
        case opener, countries, travelDays, podium, longestTrip
        case firstVisits, map, photos, closer
    }

    @State private var index = 0
    /// 0…1 through the current page's dwell time.
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var dragOffset: CGFloat = 0
    @State private var shareURLs: [URL] = []

    private let pageDuration: Double = 7
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// Pages with nothing to say are dropped, not shown empty.
    private var pages: [Page] {
        var result: [Page] = [.opener, .countries, .travelDays]
        if !data.stats.topCountries.isEmpty { result.append(.podium) }
        if data.stats.longestTrip != nil { result.append(.longestTrip) }
        if !data.stats.firstVisits.isEmpty { result.append(.firstVisits) }
        result.append(.map)
        if data.photoMoments.contains(where: { data.thumbnails[$0.assetID] != nil }) {
            result.append(.photos)
        }
        result.append(.closer)
        return result
    }

    var body: some View {
        let pages = self.pages
        let current = pages[min(index, pages.count - 1)]

        ZStack {
            AuroraBackground(
                intensity: auroraIntensity(for: current),
                tint: auroraTint(for: current),
                // The story palette, not the app one. This aurora is the
                // actual visible ground here — it covers the black beneath —
                // so on a light theme it would render cream and swallow both
                // the white chrome and the story's own ink.
                palette: Story.palette
            )

            page(current)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(current)
                .transition(.opacity)

            // Tap zones: back on the left quarter, forward elsewhere.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.25)
                        .onTapGesture { goBack() }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { advance() }
                }
            }
            .onLongPressGesture(minimumDuration: 0.2, perform: {}) { pressing in
                isPaused = pressing
            }

            chrome(pageCount: pages.count)
        }
        .offset(y: dragOffset)
        .scaleEffect(1 - min(dragOffset, 300) / 3000, anchor: .top)
        // Backstop only — the aurora above is opaque and covers this. Wrapped
        // is a full-screen story with its own per-scene mood colours, the way
        // Instagram stories ignore app chrome, so it stays dark in every
        // theme. What actually guarantees that is `Story.palette` on the
        // aurora, not this line; the white chrome below depends on it.
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: index)
        .gesture(dismissDrag)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onReceive(tick) { _ in
            guard !isPaused, dragOffset == 0, scenePhase == .active else { return }
            progress += (1.0 / 30.0) / pageDuration
            if progress >= 1 { advance() }
        }
        .task {
            // Let the opener land before paying the ImageRenderer cost.
            try? await Task.sleep(nanoseconds: 600_000_000)
            shareURLs = WrappedShareRenderer.renderCards(for: data)
        }
    }

    @ViewBuilder
    private func page(_ page: Page) -> some View {
        switch page {
        case .opener: WrappedOpenerPage(data: data)
        case .countries: WrappedCountriesPage(data: data)
        case .travelDays: WrappedTravelDaysPage(data: data)
        case .podium: WrappedPodiumPage(data: data)
        case .longestTrip: WrappedLongestTripPage(data: data)
        case .firstVisits: WrappedFirstVisitsPage(data: data)
        case .map: WrappedMapPage(data: data)
        case .photos: WrappedPhotosPage(data: data)
        case .closer: WrappedCloserPage(data: data, shareURLs: shareURLs)
        }
    }

    /// The map and photo pages want a calmer sky behind them.
    private func auroraIntensity(for page: Page) -> Double {
        switch page {
        case .map, .photos: return 0.45
        case .closer: return 0.7
        default: return 1.0
        }
    }

    /// Each scene leans the aurora toward its mood.
    private func auroraTint(for page: Page) -> Color? {
        switch page {
        case .podium, .firstVisits: return Story.amber
        case .longestTrip: return Story.aurora2
        case .travelDays: return Story.aurora1
        default: return nil
        }
    }

    // MARK: - Chrome

    private func chrome(pageCount: Int) -> some View {
        VStack {
            HStack(spacing: 4) {
                ForEach(0..<pageCount, id: \.self) { i in
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.white.opacity(0.22))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: geo.size.width * segmentFill(i))
                            }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            HStack {
                Spacer()
                if !shareURLs.isEmpty {
                    ShareLink(items: shareURLs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.25), in: Circle())
                    }
                    .simultaneousGesture(TapGesture().onEnded { isPaused = true })
                    .padding(.top, 6)
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.25), in: Circle())
                }
                .padding(.trailing, 12)
                .padding(.top, 6)
            }
            Spacer()
        }
    }

    private func segmentFill(_ i: Int) -> CGFloat {
        if i < index { return 1 }
        if i > index { return 0 }
        return CGFloat(progress)
    }

    // MARK: - Navigation

    private func advance() {
        if index < pages.count - 1 {
            index += 1
            progress = 0
            HapticsDirector.shared.tick()
        } else {
            dismiss()
        }
    }

    private func goBack() {
        // IG rule: early in a page, go back a page; deep in, restart it.
        if index > 0, progress < 0.3 {
            index -= 1
            HapticsDirector.shared.tick()
        }
        progress = 0
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 140 {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.35)) { dragOffset = 0 }
                }
            }
    }
}
