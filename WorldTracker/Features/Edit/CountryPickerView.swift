import SwiftUI
import WorldTrackerKit

/// Searchable country picker with Popular + Recent shortcuts.
struct CountryPickerView: View {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private static let popular = ["US", "GB", "DE", "FR", "ES", "IT", "PT"]

    private static let allCodes: [String] = {
        Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
            .filter { Locale.current.localizedString(forRegionCode: $0) != nil }
            .sorted { countryName($0) < countryName($1) }
    }()

    private var recent: [String] {
        UserDefaults.standard.stringArray(forKey: "recentCountries") ?? []
    }

    /// Home + your most-visited countries — the ones you actually pick.
    private var yours: [String] {
        let store = AppContainer.shared.ledgerStore
        let today = store.todayEpoch
        let earliest = min(store.earliestDay ?? today, today)
        let ranked = store.stats(in: earliest...today).daysPerCountry
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map(\.key)
        var result: [String] = []
        if let home = store.homeCountry { result.append(home) }
        for code in ranked where !result.contains(code) {
            result.append(code)
            if result.count == 5 { break }
        }
        return result
    }

    private var filtered: [String] {
        guard !query.isEmpty else { return Self.allCodes }
        return Self.allCodes.filter {
            countryName($0).localizedCaseInsensitiveContains(query)
                || $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    if !yours.isEmpty {
                        Section("Yours") {
                            yourChips
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    if !recent.isEmpty {
                        Section("Recent") {
                            ForEach(recent, id: \.self, content: row)
                        }
                    }
                    Section("Popular") {
                        ForEach(Self.popular.filter { !yours.contains($0) }, id: \.self, content: row)
                    }
                }
                Section(query.isEmpty ? "All countries" : "Results") {
                    ForEach(filtered, id: \.self, content: row)
                }
            }
            .searchable(text: $query, prompt: "Search countries")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.sky)
        }
    }

    /// Big one-tap chips: home first, then your most-visited.
    private var yourChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(yours, id: \.self) { code in
                    Button {
                        pick(code)
                    } label: {
                        HStack(spacing: 6) {
                            Text(flagEmoji(code)).font(.system(size: 18))
                            Text(countryName(code))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if code == AppContainer.shared.ledgerStore.homeCountry {
                                Text("HOME")
                                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Theme.amber)
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Theme.card)
                                .overlay(Capsule().strokeBorder(Theme.aurora1.opacity(0.4), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func pick(_ code: String) {
        var recents = recent.filter { $0 != code }
        recents.insert(code, at: 0)
        UserDefaults.standard.set(Array(recents.prefix(6)), forKey: "recentCountries")
        onPick(code)
        dismiss()
    }

    private func row(_ code: String) -> some View {
        Button {
            pick(code)
        } label: {
            HStack(spacing: 12) {
                Text(flagEmoji(code)).font(.system(size: 22))
                Text(countryName(code)).foregroundStyle(Theme.ink)
                Spacer()
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }
}

#Preview {
    CountryPickerView { _ in }
        .preferredColorScheme(.dark)
}
