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
                    if !recent.isEmpty {
                        Section("Recent") {
                            ForEach(recent, id: \.self, content: row)
                        }
                    }
                    Section("Popular") {
                        ForEach(Self.popular, id: \.self, content: row)
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

    private func row(_ code: String) -> some View {
        Button {
            var recents = recent.filter { $0 != code }
            recents.insert(code, at: 0)
            UserDefaults.standard.set(Array(recents.prefix(6)), forKey: "recentCountries")
            onPick(code)
            dismiss()
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
