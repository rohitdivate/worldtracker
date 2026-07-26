import SwiftUI
import WorldTrackerKit

/// The differentiator: not just countries — the market, the museum, the park.
/// Organized like the best saved-places UIs: search, category filter, sort,
/// and collapsible country sections instead of one endless feed.
struct PlacesListView: View {
    @State private var places: [PlaceSnapshot] = []
    @State private var filter: CategoryFilter = .all
    @State private var sort: SortMode = .grouped
    @State private var query = ""
    @State private var expandedCountries: Set<String> = []
    @State private var didSeedExpansion = false

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

    enum SortMode: String, CaseIterable, Identifiable {
        case grouped = "Grouped by country"
        case mostVisited = "Most visited"
        case recent = "Recently visited"
        case alphabetical = "A to Z"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .grouped: return "folder"
            case .mostVisited: return "flame"
            case .recent: return "clock"
            case .alphabetical: return "textformat.abc"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sky.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryStrip
                        categoryBar

                        if filtered.isEmpty {
                            emptyState
                        } else if sort == .grouped {
                            groupedList
                        } else {
                            flatList
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Places")
            .searchable(text: $query, prompt: "Search places and cities")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(SortMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationDestination(for: PlaceSnapshot.self) { place in
                PlaceDetailView(place: place, onChanged: reload)
            }
            .task { reload() }
            .refreshable { reload() }
        }
    }

    // MARK: - Data shaping

    private var filtered: [PlaceSnapshot] {
        var result = places.filter { filter.matches($0.categoryRaw) }
        if !query.isEmpty {
            result = result.filter { place in
                place.name.localizedCaseInsensitiveContains(query)
                    || (place.city?.localizedCaseInsensitiveContains(query) ?? false)
                    || (place.countryCode.map { countryName($0) }?
                        .localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return result
    }

    private func sorted(_ list: [PlaceSnapshot]) -> [PlaceSnapshot] {
        switch sort {
        case .grouped, .mostVisited:
            return list.sorted { ($0.visitCount, $1.name) > ($1.visitCount, $0.name) }
        case .recent:
            return list.sorted { ($0.lastVisit ?? .distantPast) > ($1.lastVisit ?? .distantPast) }
        case .alphabetical:
            return list.sorted { $0.name < $1.name }
        }
    }

    /// The sort views: one flat ranked list across every country — the
    /// reorder is unmissable, and each row says where the place is.
    private var flatList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sort.rawValue.uppercased())
                .font(Theme.numeric(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 2)

            ForEach(sorted(filtered)) { place in
                NavigationLink(value: place) {
                    PlaceRow(place: place, showsLocation: true, showsRecency: sort == .recent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryStrip: some View {
        let cities = Set(places.compactMap(\.city)).count
        let countries = Set(places.compactMap(\.countryCode)).count
        return HStack(spacing: 0) {
            summaryTile(value: places.count, label: "PLACES")
            summaryTile(value: cities, label: "CITIES")
            summaryTile(value: countries, label: "COUNTRIES")
        }
        .padding(.vertical, 10)
        .nightCard()
    }

    private func summaryTile(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(Theme.display(20, weight: .heavy))
                .foregroundStyle(Theme.auroraGradient)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Collapsible country sections

    private var groupedList: some View {
        let byCountry = Dictionary(grouping: filtered) { $0.countryCode ?? "??" }
        let countryOrder = byCountry.keys.sorted {
            (byCountry[$0]?.count ?? 0, $1) > (byCountry[$1]?.count ?? 0, $0)
        }
        // Searching or filtering auto-expands — hidden matches are useless.
        let forceExpanded = !query.isEmpty || filter != .all

        return ForEach(countryOrder, id: \.self) { country in
            let countryPlaces = byCountry[country] ?? []
            let isExpanded = forceExpanded || expandedCountries.contains(country)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        if expandedCountries.contains(country) {
                            expandedCountries.remove(country)
                        } else {
                            expandedCountries.insert(country)
                        }
                        persistExpansion()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(flagEmoji(country)).font(.system(size: 20))
                        Text(countryName(country))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(countryPlaces.count)")
                            .font(Theme.display(11, weight: .heavy))
                            .foregroundStyle(Theme.aurora1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.card, in: Capsule())
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 13)
                    .nightCard()
                }
                .buttonStyle(.plain)

                if isExpanded {
                    citySections(for: countryPlaces)
                        .padding(.leading, 4)
                }
            }
        }
    }

    private func citySections(for countryPlaces: [PlaceSnapshot]) -> some View {
        let byCity = Dictionary(grouping: countryPlaces) { $0.city ?? "Elsewhere" }
        let cityOrder = byCity.keys.sorted {
            (byCity[$0]?.count ?? 0, $1) > (byCity[$1]?.count ?? 0, $0)
        }

        return ForEach(cityOrder, id: \.self) { city in
            VStack(alignment: .leading, spacing: 7) {
                Text("\(city.uppercased()) · \(byCity[city]?.count ?? 0)")
                    .font(Theme.numeric(10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 4)

                ForEach(sorted(byCity[city] ?? [])) { place in
                    NavigationLink(value: place) {
                        PlaceRow(place: place)
                    }
                    .buttonStyle(.plain)
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
            Text(query.isEmpty ? "No places yet" : "No matches")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(query.isEmpty
                 ? "Spend 30+ minutes somewhere with the app installed, or run the photo Time Machine — the shops, parks and museums you visit will collect here, named automatically."
                 : "Nothing matches \"\(query)\" in this category.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    // MARK: - State

    private func reload() {
        Task {
            places = await AppContainer.shared.placesEngine.allPlaces()
            seedExpansionIfNeeded()
        }
    }

    /// First launch of the screen: restore the saved expansion, or expand
    /// just the biggest country so the list opens organized, not endless.
    private func seedExpansionIfNeeded() {
        guard !didSeedExpansion else { return }
        didSeedExpansion = true
        if let saved = UserDefaults.standard.stringArray(forKey: "placesExpanded") {
            expandedCountries = Set(saved)
            return
        }
        let byCountry = Dictionary(grouping: places) { $0.countryCode ?? "??" }
        if byCountry.count <= 2 {
            expandedCountries = Set(byCountry.keys)
        } else if let biggest = byCountry.max(by: { $0.value.count < $1.value.count }) {
            expandedCountries = [biggest.key]
        }
    }

    private func persistExpansion() {
        UserDefaults.standard.set(Array(expandedCountries), forKey: "placesExpanded")
    }
}

struct PlaceRow: View {
    let place: PlaceSnapshot
    /// Flat sort views show where the place is; grouped views already do.
    var showsLocation: Bool = false
    /// Recently-visited sort leads with WHEN instead of how often.
    var showsRecency: Bool = false

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
                    if showsLocation, let country = place.countryCode {
                        Text(flagEmoji(country))
                        if let city = place.city {
                            Text(city)
                        }
                        Text("·")
                    }
                    Text(PlaceCategoryStyle.label(place.categoryRaw))
                    if !showsLocation, let area = place.subLocality {
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
                if showsRecency, let last = place.lastVisit {
                    Text(last.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.aurora1)
                        .lineLimit(1)
                    Text("\(place.visitCount) \(place.visitCount == 1 ? "VISIT" : "VISITS")")
                        .font(.system(size: 7.5, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.ink3)
                } else {
                    Text("\(place.visitCount)")
                        .font(Theme.display(15, weight: .heavy))
                        .foregroundStyle(Theme.aurora1)
                    Text(place.visitCount == 1 ? "VISIT" : "VISITS")
                        .font(.system(size: 7.5, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.ink3)
                }
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
