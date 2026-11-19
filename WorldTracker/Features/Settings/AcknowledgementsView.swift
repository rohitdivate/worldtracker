import SwiftUI

/// Credits for the map data bundled in the app. GeoNames is licensed under
/// CC BY 4.0, which requires attribution inside the product; Natural Earth
/// and OurAirports are public domain and credited as a courtesy.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Group {
                Section {
                    credit(
                        name: "GeoNames",
                        detail: "City and region names come from the GeoNames geographical database, licensed under Creative Commons Attribution 4.0 (CC BY 4.0). Been There bundles an adapted, reduced copy.",
                        links: [
                            ("geonames.org", "https://www.geonames.org"),
                            ("CC BY 4.0 licence", "https://creativecommons.org/licenses/by/4.0/"),
                        ]
                    )
                    credit(
                        name: "Natural Earth",
                        detail: "Country borders come from Natural Earth, free vector and raster map data in the public domain.",
                        links: [("naturalearthdata.com", "https://www.naturalearthdata.com")]
                    )
                    credit(
                        name: "OurAirports",
                        detail: "Airport locations come from OurAirports, released to the public domain.",
                        links: [("ourairports.com", "https://ourairports.com")]
                    )
                } header: {
                    Text("Map data inside the app")
                } footer: {
                    Text("Been There is not affiliated with or endorsed by these projects.")
                        .textCase(nil)
                }

                Section {
                    Text("Maps, place names and points of interest are provided by Apple Maps.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                } header: {
                    Text("Maps")
                }
            }
            .listRowBackground(Theme.card)
        }
        .navigationTitle(Theme.title("Acknowledgements"))
        .navigationBarTitleDisplayMode(.inline)
        .themedList()
    }

    private func credit(name: String, detail: String, links: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
            ForEach(links.indices, id: \.self) { index in
                if let url = URL(string: links[index].1) {
                    Link(links[index].0, destination: url)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.aurora1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { AcknowledgementsView() }
}
