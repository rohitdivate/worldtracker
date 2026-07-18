import Photos
import SwiftData
import SwiftUI
import WorldTrackerKit

/// One trip, in full: its days, its photos, its cities — and the controls
/// to reshape or remove it.
struct TripDetailView: View {
    let segment: TripSegment

    @Environment(\.dismiss) private var dismiss
    @State private var displayed: TripSegment
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var photos: [TripPhoto] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var lightbox: LightboxSelection?
    @State private var shareItem: ShareItem?

    struct TripPhoto: Identifiable {
        var id: String { assetID }
        let assetID: String
        let day: Int
        let city: String?
        let photoCount: Int
    }

    private var store: LedgerStore { AppContainer.shared.ledgerStore }
    private var edit: EditService { AppContainer.shared.editService }

    init(segment: TripSegment) {
        self.segment = segment
        _displayed = State(initialValue: segment)
    }

    var body: some View {
        let today = store.todayEpoch
        let (todayYear, _, _) = EpochDay(value: today).civil()
        let isNow = displayed.endDay >= today

        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 10) {
                    FlagChip(code: displayed.countryCode, size: 64)
                        .shadow(color: Theme.aurora1.opacity(0.3), radius: 12)
                    Text(countryName(displayed.countryCode))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        Text(DayFormat.shortRange(displayed.startDay, displayed.endDay, todayYear: todayYear))
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.ink2)
                        Text(isNow ? "NOW" : "\(displayed.dayCount) \(displayed.dayCount == 1 ? "DAY" : "DAYS")")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(isNow ? Theme.amber : Theme.aurora1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder((isNow ? Theme.amber : Theme.aurora1).opacity(0.5), lineWidth: 1)
                            )
                    }
                    if !cities.isEmpty {
                        Text(cities.joined(separator: " · "))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink3)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 8)

                // Photos
                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PHOTOS FROM THIS TRIP")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(Theme.ink3)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                            spacing: 6
                        ) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { photoIndex, photo in
                                photoTile(photo)
                                    .onTapGesture {
                                        lightbox = LightboxSelection(id: photoIndex)
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Actions
                VStack(spacing: 10) {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Edit trip", systemImage: "pencil")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.sky)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 14))
                    }

                    NavigationLink(value: displayed.countryCode) {
                        Label("View country", systemImage: "globe")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .nightCard()
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete trip", systemImage: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.alert)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 18)
        }
        .background(Theme.sky)
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sharePostcard(todayYear: todayYear)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.aurora1)
                }
            }
        }
        .sheet(item: $shareItem) { item in
            SharePreviewSheet(url: item.url)
        }
        .task { loadPhotos() }
        .onChange(of: store.changeToken) { _, _ in
            rederive()
            loadPhotos()
        }
        .fullScreenCover(item: $lightbox) { selection in
            let (todayYear, _, _) = EpochDay(value: store.todayEpoch).civil()
            PhotoLightboxView(
                items: photos.map { photo in
                    PhotoLightboxItem(
                        assetID: photo.assetID,
                        caption: [
                            photo.city ?? countryName(displayed.countryCode),
                            DayFormat.shortRange(photo.day, photo.day, todayYear: todayYear),
                        ].joined(separator: " · ")
                    )
                },
                initialIndex: selection.index
            )
        }
        .sheet(isPresented: $showEditor) {
            TripEditorView(
                prefill: .init(
                    countryCode: displayed.countryCode,
                    startDay: displayed.startDay,
                    endDay: displayed.endDay
                ),
                onDelete: { confirmDelete = true }
            )
        }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete trip", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The days become 'no data'. Automatic GPS and photo evidence is hidden, not erased — any day can be restored from its day editor. Photos stay in your library.")
        }
    }

    /// Postcard from the already-loaded thumbnails — never touches Photos.
    private func sharePostcard(todayYear: Int) {
        let images = photos.prefix(3).compactMap { thumbnails[$0.assetID] }
        guard let url = ShareCardService.render(
            TripPostcardCard(
                countryCode: displayed.countryCode,
                dateRange: DayFormat.shortRange(
                    displayed.startDay, displayed.endDay, todayYear: todayYear
                ),
                dayCount: displayed.dayCount,
                cities: cities,
                photos: Array(images)
            ),
            name: "BeenThere-Trip-\(displayed.countryCode)-\(displayed.startDay)"
        ) else { return }
        shareItem = ShareItem(url: url)
    }

    private var cities: [String] {
        var seen: Set<String> = []
        return photos.compactMap { photo in
            guard let city = photo.city, !seen.contains(city) else { return nil }
            seen.insert(city)
            return city
        }
    }

    private func photoTile(_ photo: TripPhoto) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = thumbnails[photo.assetID] {
                // Crop into the square — never squash the photo itself.
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.card)
                    .aspectRatio(1, contentMode: .fit)
            }
            if photo.photoCount > 1 {
                Text("\(photo.photoCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(4)
            }
        }
    }

    // MARK: - Data

    /// After an edit, find "the same trip" again: the segment for the
    /// editor's country overlapping the old range. Gone entirely → pop.
    private func rederive() {
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let all = store.segments(in: earliest...today)
        let match = all.first {
            $0.countryCode == displayed.countryCode
                && $0.startDay <= displayed.endDay && $0.endDay >= displayed.startDay
        }
        if let match {
            displayed = match
        } else {
            dismiss()
        }
    }

    private func loadPhotos() {
        let lower = displayed.startDay
        let upper = displayed.endDay
        let country = displayed.countryCode
        let predicate = #Predicate<PhotoEvidence> {
            $0.epochDay >= lower && $0.epochDay <= upper
        }
        let rows = (try? AppContainer.shared.modelContainer.mainContext
            .fetch(FetchDescriptor(predicate: predicate))) ?? []

        photos = rows
            .filter { $0.countryCode == country }
            .sorted { ($0.epochDay, $0.photoCount) < ($1.epochDay, $1.photoCount) }
            .compactMap { row in
                guard let assetID = row.representativeAssetID else { return nil }
                return TripPhoto(
                    assetID: assetID,
                    day: row.epochDay,
                    city: row.city,
                    photoCount: row.photoCount
                )
            }
        loadThumbnails()
    }

    /// The proven local-only recipe (no iCloud fetches for grid tiles).
    private func loadThumbnails() {
        let missing = photos.map(\.assetID).filter { thumbnails[$0] == nil }
        guard !missing.isEmpty else { return }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: missing, options: nil)
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
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image {
                    DispatchQueue.main.async {
                        thumbnails[asset.localIdentifier] = image
                    }
                }
            }
        }
    }

    private func performDelete() {
        var clearDays: [Int] = []
        var overrideDays: [(day: Int, codes: [String])] = []
        for day in displayed.startDay...displayed.endDay {
            let codes = store.day(day).countryCodes
            if codes == [displayed.countryCode] {
                clearDays.append(day)
            } else if codes.contains(displayed.countryCode) {
                overrideDays.append((day: day, codes: codes.filter { $0 != displayed.countryCode }))
            }
        }
        edit.deleteTrip(
            .init(
                countryCode: displayed.countryCode,
                range: displayed.startDay...displayed.endDay,
                clearDays: clearDays,
                overrideDays: overrideDays
            )
        )
        dismiss()
    }
}
