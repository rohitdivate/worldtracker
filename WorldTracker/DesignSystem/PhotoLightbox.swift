import Photos
import SwiftUI

/// Full-screen photo viewer: swipe between photos, pinch/double-tap zoom,
/// drag down to dismiss. Full-resolution originals load with iCloud access
/// allowed (they're the user's own library) — the local thumbnail shows
/// instantly while the original streams in.
struct PhotoLightboxItem: Identifiable, Hashable {
    var id: String { assetID }
    let assetID: String
    let caption: String?
}

struct LightboxSelection: Identifiable {
    let id: Int
    var index: Int { id }
}

struct PhotoLightboxView: View {
    let items: [PhotoLightboxItem]
    @State private var index: Int
    @State private var chromeHidden = false
    @State private var dismissDrag: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    init(items: [PhotoLightboxItem], initialIndex: Int) {
        self.items = items
        _index = State(initialValue: min(max(0, initialIndex), max(0, items.count - 1)))
    }

    var body: some View {
        ZStack {
            // Stays black in every theme, deliberately: this is a photo
            // viewer, and a cream backdrop would wreck the contrast of the
            // photo itself. Not an oversight in the light-theme audit.
            Color.black
                .opacity(1 - Double(min(dismissDrag, 300)) / 400)
                .ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { itemIndex, item in
                    ZoomablePhotoPage(
                        item: item,
                        onToggleChrome: { chromeHidden.toggle() }
                    )
                    .tag(itemIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .offset(y: dismissDrag)

            if !chromeHidden {
                chrome
            }
        }
        // Dismiss lives OUT HERE, off the pages: a high threshold plus a
        // strict vertical-dominance test keeps horizontal paging swipes
        // completely free of competition.
        .simultaneousGesture(
            DragGesture(minimumDistance: 40)
                .onChanged { value in
                    let dy = value.translation.height
                    let dx = value.translation.width
                    if dy > 0, dy > abs(dx) * 2 {
                        dismissDrag = dy
                    }
                }
                .onEnded { value in
                    if dismissDrag > 130 || value.predictedEndTranslation.height > 400 {
                        dismiss()
                    } else {
                        withAnimation(.spring(duration: 0.3)) { dismissDrag = 0 }
                    }
                }
        )
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .padding(.leading, 14)
                Spacer()
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 3) {
                if let caption = items[index].caption {
                    Text(caption)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                if items.count > 1 {
                    Text("\(index + 1) / \(items.count)")
                        .font(Theme.numeric(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 24)
        }
        .transition(.opacity)
    }
}

/// One zoomable page. Zoom state is local and resets when the page leaves.
/// Crucially: while NOT zoomed, this view attaches no drag gesture at all,
/// so the pager owns every horizontal swipe outright.
private struct ZoomablePhotoPage: View {
    let item: PhotoLightboxItem
    let onToggleChrome: () -> Void

    @State private var image: UIImage?
    @State private var isDegraded = true
    @State private var requestID: PHImageRequestID?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView()
                        .tint(.white)
                }

                if image != nil, isDegraded {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white.opacity(0.6))
                                .padding(18)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { toggleZoom() }
            .onTapGesture { onToggleChrome() }
            .gesture(magnification)
            // Pan participates ONLY while zoomed — at rest the mask hands
            // everything to the pager underneath.
            .gesture(pan(in: geo.size), including: scale > 1 ? .all : .subviews)
        }
        .task(id: item.assetID) { load() }
        .onDisappear {
            if let requestID {
                PHImageManager.default().cancelImageRequest(requestID)
            }
            resetZoom()
        }
    }

    // MARK: - Gestures

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(4, max(0.8, lastScale * value.magnification))
            }
            .onEnded { _ in
                if scale < 1 {
                    withAnimation(.spring(duration: 0.3)) {
                        scale = 1
                        offset = .zero
                    }
                }
                lastScale = max(1, scale)
                lastOffset = offset
            }
    }

    /// Pan the zoomed image. Never active at scale 1.
    private func pan(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = clampedOffset(in: size)
                withAnimation(.spring(duration: 0.25)) { offset = lastOffset }
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(duration: 0.3)) {
            if scale > 1.01 {
                resetZoom()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private func clampedOffset(in size: CGSize) -> CGSize {
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }

    // MARK: - Loading

    private func load() {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [item.assetID], options: nil)
        guard let asset = fetch.firstObject else { return }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true   // the user's own iCloud originals
        options.deliveryMode = .opportunistic
        options.resizeMode = .none
        options.isSynchronous = false

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { result, info in
            guard let result else { return }
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            DispatchQueue.main.async {
                // Never let a late degraded frame stomp the full-res one.
                if degraded, image != nil, !isDegraded { return }
                image = result
                isDegraded = degraded
            }
        }
    }
}
