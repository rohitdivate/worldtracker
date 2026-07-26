import MapKit
import Photos
import SwiftUI
import WorldTrackerKit

/// One place's story: mini-map, your photos taken there, every visit.
struct PlaceDetailView: View {
    let place: PlaceSnapshot
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var visits: [VisitSnapshot] = []
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var lightbox: LightboxSelection?

    var body: some View {
        ZStack {
            Theme.sky.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    map

                    HStack(spacing: 12) {
                        Text(PlaceCategoryStyle.emoji(place.categoryRaw))
                            .font(.system(size: 30))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(Theme.display(22, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink3)
                        }
                        Spacer()
                    }

                    let assetIDs = Array(visits.flatMap(\.assetIDs).prefix(24))
                    if !assetIDs.isEmpty {
                        PhotoStrip(assetIDs: assetIDs) { index in
                            lightbox = LightboxSelection(id: index)
                        }
                        .fullScreenCover(item: $lightbox) { selection in
                            PhotoLightboxView(
                                items: assetIDs.map {
                                    PhotoLightboxItem(assetID: $0, caption: place.name)
                                },
                                initialIndex: selection.index
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("VISITS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(Theme.ink3)

                        ForEach(visits) { visit in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visitTitle(visit))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    if let duration = visitDuration(visit) {
                                        Text(duration)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.ink3)
                                    }
                                }
                                Spacer()
                                ProvenanceStamp(source: visit.sourceRaw == "photo" ? .photo : .visit)
                            }
                            .padding(12)
                            .nightCard()
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Rename") {
                        newName = place.name
                        isRenaming = true
                    }
                    Button("Delete place", role: .destructive) {
                        Task {
                            await AppContainer.shared.placesEngine.delete(placeID: place.id)
                            onChanged()
                            dismiss()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.aurora1)
                }
            }
        }
        .alert("Rename place", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                Task {
                    await AppContainer.shared.placesEngine.rename(placeID: place.id, to: newName)
                    onChanged()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            visits = await AppContainer.shared.placesEngine.visits(for: place.id)
        }
    }

    private var map: some View {
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        return Map(initialPosition: .region(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 600,
                longitudinalMeters: 600
            )
        )) {
            Annotation(place.name, coordinate: coordinate) {
                Text(PlaceCategoryStyle.emoji(place.categoryRaw))
                    .font(.system(size: 22))
                    .padding(6)
                    .background(Theme.skyRaised, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.aurora1, lineWidth: 1.5))
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .allowsHitTesting(false)
    }

    private var subtitle: String {
        var parts: [String] = [PlaceCategoryStyle.label(place.categoryRaw)]
        if let area = place.subLocality { parts.append(area) }
        if let city = place.city { parts.append(city) }
        if let country = place.countryCode { parts.append(countryName(country)) }
        return parts.joined(separator: " · ")
    }

    private func visitTitle(_ visit: VisitSnapshot) -> String {
        guard let date = visit.arrival ?? visit.departure else {
            let (y, m, d) = EpochDay(value: visit.epochDay).civil()
            return "\(d)/\(m)/\(y)"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func visitDuration(_ visit: VisitSnapshot) -> String? {
        guard let arrival = visit.arrival, let departure = visit.departure else { return nil }
        let minutes = Int(departure.timeIntervalSince(arrival) / 60)
        guard minutes > 0 else { return nil }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// Horizontal strip of the photos taken at this place — strictly local
/// thumbnails (no iCloud downloads; missing originals just don't appear).
struct PhotoStrip: View {
    let assetIDs: [String]
    /// Tap on a tile → index into `assetIDs` (nil keeps tiles inert).
    var onTap: ((Int) -> Void)? = nil

    @State private var images: [String: UIImage] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(assetIDs, id: \.self) { id in
                    if let image = images[id] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .transition(.opacity.combined(with: .scale(scale: 1.15)))
                            .onTapGesture {
                                if let index = assetIDs.firstIndex(of: id) {
                                    onTap?(index)
                                }
                            }
                    }
                }
            }
        }
        .animation(.spring(duration: 0.4), value: images.count)
        .task { await loadThumbnails() }
    }

    private func loadThumbnails() async {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        for asset in assets {
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image {
                    Task { @MainActor in
                        images[asset.localIdentifier] = image
                    }
                }
            }
        }
    }
}
