import Foundation

/// The seven continents, in the order the Passport tab draws them.
public enum Continent: String, CaseIterable, Sendable, Codable, Identifiable {
    case europe
    case asia
    case africa
    case northAmerica
    case southAmerica
    case oceania
    case antarctica

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .europe: "Europe"
        case .asia: "Asia"
        case .africa: "Africa"
        case .northAmerica: "North America"
        case .southAmerica: "South America"
        case .oceania: "Oceania"
        case .antarctica: "Antarctica"
        }
    }

    /// Three letters for tight spots (widgets, ring captions).
    public var shortName: String {
        switch self {
        case .europe: "EUR"
        case .asia: "ASI"
        case .africa: "AFR"
        case .northAmerica: "NAM"
        case .southAmerica: "SAM"
        case .oceania: "OCE"
        case .antarctica: "ANT"
        }
    }
}

/// ISO 3166-1 alpha-2 → continent, plus which codes are the 195 sovereign
/// states the app's "% of the world" has always been measured against.
///
/// Transcontinental states follow the usual atlas convention: Russia in
/// Europe; Turkey, Cyprus and the Caucasus in Asia; Egypt in Africa.
public enum ContinentTable {
    private static let sovereignByContinent: [Continent: String] = [
        .africa: """
            DZ AO BJ BW BF BI CV CM CF TD KM CD CG CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS \
            LR LY MG MW ML MR MU MA MZ NA NE NG RW ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW
            """,
        .asia: """
            AF AM AZ BH BD BT BN KH CN CY GE IN ID IR IQ IL JP JO KZ KW KG LA LB MY MV MN MM \
            NP KP OM PK PH PS QA SA SG KR LK SY TJ TH TL TR TM AE UZ VN YE
            """,
        .europe: """
            AL AD AT BY BE BA BG HR CZ DK EE FI FR DE GR HU IS IE IT LV LI LT LU MT MD MC ME \
            NL MK NO PL PT RO RU SM RS SK SI ES SE CH UA GB VA
            """,
        .northAmerica: "AG BS BB BZ CA CR CU DM DO SV GD GT HT HN JM MX NI PA KN LC VC TT US",
        .southAmerica: "AR BO BR CL CO EC GY PY PE SR UY VE",
        .oceania: "AU FJ KI MH FM NR NZ PW PG WS SB TO TV VU",
    ]

    /// Territories and partially recognised states: real places a traveller
    /// can stand in and the atlas can name, outside the 195.
    private static let territoriesByContinent: [Continent: String] = [
        .africa: "EH RE YT SH",
        .asia: "TW HK MO IO",
        .europe: "XK FO GI GG JE IM AX SJ",
        .northAmerica: "GL PR BM KY VG VI AI AW CW SX BQ MF BL GP MQ MS TC PM",
        .southAmerica: "GF FK",
        .oceania: "NC PF GU MP AS CK NU TK WF NF PN CX CC UM",
        .antarctica: "AQ TF HM BV GS",
    ]

    private static func codes(_ list: String) -> [String] {
        list.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
    }

    /// The 195: 193 UN members, the Holy See and Palestine.
    public static let sovereign: Set<String> = {
        Set(sovereignByContinent.values.flatMap(codes))
    }()

    private static let lookup: [String: Continent] = {
        var table: [String: Continent] = [:]
        for source in [sovereignByContinent, territoriesByContinent] {
            for (continent, list) in source {
                for code in codes(list) {
                    table[code] = continent
                }
            }
        }
        return table
    }()

    public static func continent(of code: String) -> Continent? {
        lookup[code.uppercased()]
    }

    /// Every code the table knows, sovereign or not.
    public static var allCodes: Set<String> { Set(lookup.keys) }

    /// Sovereign states on a continent: the denominator for its ring.
    public static func sovereignCount(in continent: Continent) -> Int {
        sovereignByContinent[continent].map { codes($0).count } ?? 0
    }

    /// Sovereign states on a continent, alphabetical by code.
    public static func sovereignCodes(in continent: Continent) -> [String] {
        (sovereignByContinent[continent].map(codes) ?? []).sorted()
    }
}

/// How much of one continent has been visited.
public struct ContinentProgress: Sendable, Equatable, Identifiable, Codable {
    public var id: String { continent.rawValue }
    public let continent: Continent
    /// Visited codes on this continent (territories included, the same
    /// convention the lifetime country count uses).
    public let visited: Int
    /// Sovereign states on the continent. Zero for Antarctica.
    public let total: Int

    public init(continent: Continent, visited: Int, total: Int) {
        self.continent = continent
        self.visited = visited
        self.total = total
    }

    public var fraction: Double {
        guard total > 0 else { return visited > 0 ? 1 : 0 }
        return min(1, Double(visited) / Double(total))
    }

    public static func compute(visited codes: Set<String>) -> [ContinentProgress] {
        var counts: [Continent: Int] = [:]
        for code in codes {
            if let continent = ContinentTable.continent(of: code) {
                counts[continent, default: 0] += 1
            }
        }
        return Continent.allCases.map {
            ContinentProgress(
                continent: $0,
                visited: counts[$0] ?? 0,
                total: ContinentTable.sovereignCount(in: $0)
            )
        }
    }
}
