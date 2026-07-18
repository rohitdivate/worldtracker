import SwiftUI
import WorldTrackerKit

/// The differentiator: not just countries — the market, the museum, the park.
/// Grouped by country → city, filterable by category.
struct PlacesListView: View {
    @State private var places: [PlaceSnapshot] = []
    @State private var filter: CategoryFilter = .all

    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "✦ All"
        case museums = "🏛️ Culture"
        case parks = "🌳 Outdoors"
        case food = "☕ Food & drink"
        case shops = "🛍️ Shops"
        case other = "📍 Other"

        var id: String { rawValue }

        func matches(_ categoryRaw: String?) -> Bool {
            let emoji = PlaceCategoryStyle.emoji(categoryRaw)
            switch self {
            case .all: return true
            case .museums: return ["🏛️", "🎭", "📚", "🏰", "🏟️", "🎓", "🦁", "🎢"].contains(emoji)
            case .parks: return ["🌳", "🏖️", "⛺", "⛵"].contains(emoji)
            case .food: return ["☕", "🍜", "🍷"].contains(emoji)
            case .shops: return ["🛍️"].contains(emoji)
            case .other: return ["📍", "🛏️", "✈️", "🚉", "🏋️"].contains(emoji)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sky.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        categoryBar

                        if filtered.isEmpty {
                            emptyState
                        } else {
                            groupedList
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Places")
            .navigationDestination(for: PlaceSnapshot.self) { place in
                PlaceDetailView(place: place, onChanged: reload)
            }
            .task { reload() }
            .refreshable { reload() }
        }
    }

    private var filtered: [PlaceSnapshot] {
        places.filter { filter.matches($0.categoryRaw) }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CategoryFilter.allCases) { category in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { filter = category }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    filter == category
                                        ? AnyShapeStyle(Theme.auroraGradient)
                                        : AnyShapeStyle(Theme.card)
                                )
                            )
                            .foregroundStyle(filter == category ? Theme.sky : Theme.ink2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var groupedList: some View {
        // country → city → places
        let byCountry = Dictionary(grouping: filtered) { $0.countryCode ?? "??" }
        let countryOrder = byCountry.keys.sorted {
            (byCountry[$0]?.count ?? 0, $1) > (byCountry[$1]?.count ?? 0, $0)
        }

        return ForEach(countryOrder, id: \.self) { country in
            let countryPlaces = byCountry[country] ?? []
            let byCity = Dictionary(grouping: countryPlaces) { $0.city ?? "Elsewhere" }
            let cityOrder = byCity.keys.sorted {
                (byCity[$0]?.count ?? 0, $1) > (byCity[$1]?.count ?? 0, $0)
            }

            ForEach(cityOrder, id: \.self) { city in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(flagEmoji(country)).font(.system(size: 15))
                        Text(city)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(byCity[city]?.count ?? 0) PLACES")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.ink3)
                    }
                    .padding(.top, 8)

                    ForEach(byCity[city] ?? []) { place in
                        NavigationLink(value: place) {
                            PlaceRow(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 38))
                .foregroundStyle(Theme.auroraGradient)
                .symbolEffect(.breathe)
            Text("No places yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Spend 30+ minutes somewhere with the app installed, or run the photo Time Machine — the shops, parks and museums you visit will collect here, named automatically.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    private func reload() {
        Task {
            places = await AppContainer.shared.placesEngine.allPlaces()
        }
    }
}

struct PlaceRow: View {
    let place: PlaceSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text(PlaceCategoryStyle.emoji(place.categoryRaw))
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(PlaceCategoryStyle.label(place.categoryRaw))
                    if let area = place.subLocality {
                        Text("·")
                        Text(area)
                    }
                    if place.isNamePending {
                        Text("· naming…")
                            .foregroundStyle(Theme.aurora2)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(place.visitCount)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.aurora1)
                Text(place.visitCount == 1 ? "VISIT" : "VISITS")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .nightCard()
    }
}

#Preview {
    PlacesListView()
        .preferredColorScheme(.dark)
}
