import Foundation

/// Theme palettes as plain numbers, so both the app and the widget extension
/// read one definition instead of two hand-synced copies.
///
/// `SwiftUI.Color` deliberately does not appear here — SwiftUI does not exist
/// on Linux, and keeping palettes in the Kit is what makes them testable
/// without a Mac. Each target maps `ColorToken` to its own `Color`.

/// One colour, as straight sRGB components in 0…1 plus an alpha.
public struct ColorToken: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Build from a hex literal, which is how the source palettes are written
    /// down — `0xFEF7EE` stays greppable against the design reference.
    public init(hex: UInt32, alpha: Double = 1.0) {
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
        self.alpha = alpha
    }

    /// Same colour, different opacity — for deriving the `ink` ramps and
    /// hairlines that several palettes express as one colour at N%.
    public func opacity(_ value: Double) -> ColorToken {
        ColorToken(red: red, green: green, blue: blue, alpha: value)
    }

    /// Relative luminance per WCAG 2.1, used by the contrast tests.
    public var luminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Flatten this colour onto an opaque background, honouring its alpha.
    /// Several palettes express `ink2`/`ink3` as one colour at a percentage,
    /// and what the eye actually sees is the composite.
    public func composited(over background: ColorToken) -> ColorToken {
        guard alpha < 1 else { return self }
        func blend(_ f: Double, _ b: Double) -> Double { f * alpha + b * (1 - alpha) }
        return ColorToken(
            red: blend(red, background.red),
            green: blend(green, background.green),
            blue: blend(blue, background.blue)
        )
    }

    /// WCAG contrast ratio of this colour as *foreground* over `other` as
    /// background, 1…21. A translucent foreground is composited first —
    /// measuring it as opaque would overstate the contrast and let an
    /// effectively invisible token pass a legibility test.
    public func contrastRatio(against other: ColorToken) -> Double {
        let a = composited(over: other).luminance + 0.05
        let b = other.luminance + 0.05
        return max(a, b) / min(a, b)
    }
}

/// Which system font design a palette leans on. Mirrors
/// `SwiftUI.Font.Design` without importing SwiftUI; the app maps it across.
public enum FontDesignToken: String, CaseIterable, Sendable {
    case standard
    case rounded
    case serif
    case monospaced
    /// The system face at its widest: the bold skins' headline word.
    case expanded
    /// The system face at its narrowest: poster numerals and screen titles.
    case compressed
}

/// How a skin draws its surfaces, beyond which colours it uses.
public enum ThemeStyle: String, Sendable {
    /// The original look: aurora mesh, gradient fills, hairline-edged cards.
    case aurora
    /// Flat grounds, solid ink fills, borderless cards, poster numerals,
    /// mono caps labels, and a 3D hero object on Home.
    case bold
}

/// The themes a user can pick. Raw values are persisted in UserDefaults and
/// shared with the widget through the App Group — don't rename them.
public enum ThemeID: String, CaseIterable, Identifiable, Sendable {
    // The bold skins come first: that is the order the picker shows them.
    case paper
    case graphite
    case hiVis
    case poolside
    case nightFlight
    case tropicalSpritz
    case mercuryDark

    public var id: String { rawValue }

    /// Falls back rather than failing: an unknown stored value (older build,
    /// hand-edited defaults) should look like the default theme, not crash.
    public init(storedValue: String?) {
        self = ThemeID(rawValue: storedValue ?? "") ?? .default
    }

    /// Paper since 2.0. An install that never picked a theme moves to it;
    /// one that picked a classic keeps its choice.
    public static var `default`: ThemeID { .paper }

    /// The skins that predate the bold redesign, grouped in the picker.
    public var isClassic: Bool {
        switch self {
        case .nightFlight, .tropicalSpritz, .mercuryDark: true
        default: false
        }
    }

    public var displayName: String {
        switch self {
        case .paper: "Paper"
        case .graphite: "Graphite"
        case .hiVis: "Hi-Vis"
        case .poolside: "Poolside"
        case .nightFlight: "Night Flight"
        case .tropicalSpritz: "Tropical Spritz"
        case .mercuryDark: "Mercury Dark"
        }
    }

    /// One line for the Settings row — what the theme feels like, not a colour list.
    public var tagline: String {
        switch self {
        case .paper: "Grey paper, black ink, one red. The default."
        case .graphite: "The same ink, lights off."
        case .hiVis: "Painted industrial yellow."
        case .poolside: "Pale water blue and navy."
        case .nightFlight: "Deep indigo and aurora. The original."
        case .tropicalSpritz: "Warm cream, hibiscus and lagoon. Light."
        case .mercuryDark: "Near-black surfaces, electric lime, mono numerals."
        }
    }

    public var palette: ThemePalette { ThemePalette.palette(for: self) }

    /// The palette for full-screen story surfaces that stay black in every
    /// theme — Wrapped, today. Those surfaces can't use `palette`: on a light
    /// theme its ink is dark (invisible on black) and its cards are pale
    /// (glaring on black). Always dark, whatever the app theme.
    public var storyPalette: ThemePalette { ThemePalette.storyPalette(for: self) }
}

/// Every colour and font decision a theme makes. Adding a token here forces
/// all three palettes to supply it, which is the point.
public struct ThemePalette: Sendable {
    public let id: ThemeID

    /// True for light themes. Drives `preferredColorScheme` so status bar and
    /// system controls follow, and flags which surfaces need the light audit.
    public let isLight: Bool

    // Grounds
    public let sky: ColorToken
    public let skyRaised: ColorToken
    public let card: ColorToken
    public let cardRaised: ColorToken

    // Ink
    public let ink: ColorToken
    public let ink2: ColorToken
    public let ink3: ColorToken

    // Accents
    public let aurora1: ColorToken
    public let aurora2: ColorToken
    public let amber: ColorToken

    // Semantic
    public let good: ColorToken
    public let alert: ColorToken

    // Lines. Both are one tint at two strengths, matching the original tokens.
    public let hairline: ColorToken
    public let hairline2: ColorToken

    /// Low-opacity overlay for chip rings and gloss highlights. Was a bare
    /// `Color.white` before themes; on a light ground white is invisible.
    public let gloss: ColorToken

    /// Ocean fill for the mini globe, previously hardcoded.
    public let globeOcean: ColorToken

    // Typography — applied only to identity-carrying surfaces.
    public let displayDesign: FontDesignToken
    public let numericDesign: FontDesignToken
    public let bodyDesign: FontDesignToken

    // Added with the bold skins. Defaulted, so the classic palettes read
    // exactly as they did.

    public var style: ThemeStyle = .aurora
    /// Poster numerals and screen titles. Nil = the display face.
    public var posterDesign: FontDesignToken? = nil
    /// Small counts and day figures (was a hardcoded rounded face).
    public var figureDesign: FontDesignToken = .rounded
    /// Tracked caps labels.
    public var labelDesign: FontDesignToken = .standard

    public var isBold: Bool { style == .bold }

    public static func palette(for id: ThemeID) -> ThemePalette {
        switch id {
        case .paper: paper
        case .graphite: graphite
        case .hiVis: hiVis
        case .poolside: poolside
        case .nightFlight: nightFlight
        case .tropicalSpritz: tropicalSpritz
        case .mercuryDark: mercuryDark
        }
    }

    /// Palette for the always-black story surfaces. Dark themes are already
    /// legible there and pass straight through; a light theme needs a dark
    /// counterpart or its ink disappears.
    public static func storyPalette(for id: ThemeID) -> ThemePalette {
        switch id {
        case .paper: graphiteStory(for: .paper, accent: graphite.aurora1)
        case .graphite: graphite
        case .hiVis: graphiteStory(for: .hiVis, accent: hiVis.sky)
        case .poolside: graphiteStory(for: .poolside, accent: poolside.sky)
        case .nightFlight: nightFlight
        case .tropicalSpritz: tropicalSpritzStory
        case .mercuryDark: mercuryDark
        }
    }

    // MARK: - Bold skins
    //
    // One ground, one ink, one loud "now" colour, one data colour. The ink
    // doubles as the second accent, so fills and big numerals are solid
    // rather than gradients.

    /// Light grey paper, white cards, black ink, signal red for now and
    /// home, blue for data.
    public static let paper = ThemePalette(
        id: .paper,
        isLight: true,
        sky: ColorToken(hex: 0xE9E9E6),
        skyRaised: ColorToken(hex: 0xF0F0ED),
        card: ColorToken(hex: 0xFFFFFF),
        cardRaised: ColorToken(hex: 0xFFFFFF),
        ink: ColorToken(hex: 0x111111),
        ink2: ColorToken(hex: 0x111111).opacity(0.64),
        ink3: ColorToken(hex: 0x111111).opacity(0.50),
        // Deepened from the bright data blue (#1FA8FF, 2.6:1 on this ground)
        // until it clears AA as text, which is how this app uses accents.
        aurora1: ColorToken(hex: 0x0A5FCC),
        aurora2: ColorToken(hex: 0x111111),
        amber: ColorToken(hex: 0xB93A08),
        good: ColorToken(hex: 0x116B33),
        alert: ColorToken(hex: 0xB00020),
        hairline: ColorToken(hex: 0x111111).opacity(0.10),
        hairline2: ColorToken(hex: 0x111111).opacity(0.18),
        gloss: ColorToken(hex: 0x111111).opacity(0.14),
        globeOcean: ColorToken(hex: 0x111111),
        displayDesign: .expanded,
        numericDesign: .monospaced,
        bodyDesign: .standard,
        style: .bold,
        posterDesign: .compressed,
        figureDesign: .monospaced,
        labelDesign: .monospaced
    )

    /// Paper with the lights off.
    public static let graphite = ThemePalette(
        id: .graphite,
        isLight: false,
        sky: ColorToken(hex: 0x161616),
        skyRaised: ColorToken(hex: 0x1C1C1C),
        card: ColorToken(hex: 0x232323),
        cardRaised: ColorToken(hex: 0x2A2A2A),
        ink: ColorToken(hex: 0xF2F2F0),
        ink2: ColorToken(hex: 0xF2F2F0).opacity(0.64),
        ink3: ColorToken(hex: 0xF2F2F0).opacity(0.46),
        aurora1: ColorToken(hex: 0x4DB8FF),
        aurora2: ColorToken(hex: 0xF2F2F0),
        amber: ColorToken(hex: 0xFF5A4D),
        good: ColorToken(hex: 0x4ADE80),
        alert: ColorToken(hex: 0xFF6B9A),
        hairline: ColorToken(hex: 0xFFFFFF).opacity(0.10),
        hairline2: ColorToken(hex: 0xFFFFFF).opacity(0.18),
        gloss: ColorToken(hex: 0xFFFFFF).opacity(0.20),
        globeOcean: ColorToken(hex: 0x6A6A6A),
        displayDesign: .expanded,
        numericDesign: .monospaced,
        bodyDesign: .standard,
        style: .bold,
        posterDesign: .compressed,
        figureDesign: .monospaced,
        labelDesign: .monospaced
    )

    /// The material of work: excavator yellow with black ink.
    public static let hiVis = ThemePalette(
        id: .hiVis,
        isLight: true,
        sky: ColorToken(hex: 0xF2B824),
        skyRaised: ColorToken(hex: 0xF4BF38),
        card: ColorToken(hex: 0xF8D261),
        cardRaised: ColorToken(hex: 0xFADB7D),
        ink: ColorToken(hex: 0x111111),
        ink2: ColorToken(hex: 0x111111).opacity(0.70),
        ink3: ColorToken(hex: 0x111111).opacity(0.58),
        // Everything painted on yellow has to be very dark to read.
        aurora1: ColorToken(hex: 0x0A3D91),
        aurora2: ColorToken(hex: 0x111111),
        amber: ColorToken(hex: 0x96130A),
        good: ColorToken(hex: 0x0D5226),
        alert: ColorToken(hex: 0x7A0A3C),
        hairline: ColorToken(hex: 0x111111).opacity(0.12),
        hairline2: ColorToken(hex: 0x111111).opacity(0.22),
        gloss: ColorToken(hex: 0x111111).opacity(0.16),
        globeOcean: ColorToken(hex: 0x111111),
        displayDesign: .expanded,
        numericDesign: .monospaced,
        bodyDesign: .standard,
        style: .bold,
        posterDesign: .compressed,
        figureDesign: .monospaced,
        labelDesign: .monospaced
    )

    /// Pale water blue with navy ink.
    public static let poolside = ThemePalette(
        id: .poolside,
        isLight: true,
        sky: ColorToken(hex: 0x86D3F6),
        skyRaised: ColorToken(hex: 0x93D8F7),
        card: ColorToken(hex: 0xB5E5FA),
        cardRaised: ColorToken(hex: 0xC8ECFC),
        ink: ColorToken(hex: 0x06243F),
        ink2: ColorToken(hex: 0x06243F).opacity(0.72),
        ink3: ColorToken(hex: 0x06243F).opacity(0.60),
        aurora1: ColorToken(hex: 0x0A4697),
        aurora2: ColorToken(hex: 0x06243F),
        amber: ColorToken(hex: 0x9E150B),
        good: ColorToken(hex: 0x0C5227),
        alert: ColorToken(hex: 0x850B43),
        hairline: ColorToken(hex: 0x06243F).opacity(0.12),
        hairline2: ColorToken(hex: 0x06243F).opacity(0.22),
        gloss: ColorToken(hex: 0x06243F).opacity(0.16),
        globeOcean: ColorToken(hex: 0x06243F),
        displayDesign: .expanded,
        numericDesign: .monospaced,
        bodyDesign: .standard,
        style: .bold,
        posterDesign: .compressed,
        figureDesign: .monospaced,
        labelDesign: .monospaced
    )

    /// A light bold skin on the black story surface: Graphite's grounds and
    /// ink, with the skin's own colour as the data accent so the story still
    /// reads as that skin.
    static func graphiteStory(for id: ThemeID, accent: ColorToken) -> ThemePalette {
        ThemePalette(
            id: id,
            isLight: false,
            sky: graphite.sky,
            skyRaised: graphite.skyRaised,
            card: graphite.card,
            cardRaised: graphite.cardRaised,
            ink: graphite.ink,
            ink2: graphite.ink2,
            ink3: graphite.ink3,
            aurora1: accent,
            aurora2: graphite.aurora2,
            amber: graphite.amber,
            good: graphite.good,
            alert: graphite.alert,
            hairline: graphite.hairline,
            hairline2: graphite.hairline2,
            gloss: graphite.gloss,
            globeOcean: graphite.globeOcean,
            displayDesign: .expanded,
            numericDesign: .monospaced,
            bodyDesign: .standard,
            style: .bold,
            posterDesign: .compressed,
            figureDesign: .monospaced,
            labelDesign: .monospaced
        )
    }

    /// The original identity. Values are byte-for-byte the pre-theme
    /// constants, so selecting this must look exactly like before.
    public static let nightFlight = ThemePalette(
        id: .nightFlight,
        isLight: false,
        sky: ColorToken(hex: 0x070B16),
        skyRaised: ColorToken(hex: 0x0C1322),
        card: ColorToken(hex: 0x131C31),
        cardRaised: ColorToken(hex: 0x151F38),
        ink: ColorToken(hex: 0xEDF2FF),
        ink2: ColorToken(hex: 0x8E9BC0),
        ink3: ColorToken(hex: 0x55628A),
        aurora1: ColorToken(hex: 0x59E3C8),
        aurora2: ColorToken(hex: 0x7B8CFF),
        amber: ColorToken(hex: 0xFFB74D),
        good: ColorToken(hex: 0x4ADE80),
        alert: ColorToken(hex: 0xF87171),
        hairline: ColorToken(hex: 0x9DB2FF).opacity(0.10),
        hairline2: ColorToken(hex: 0x9DB2FF).opacity(0.18),
        gloss: ColorToken(hex: 0xFFFFFF).opacity(0.25),
        globeOcean: ColorToken(hex: 0x2E8FB8),
        displayDesign: .rounded,
        numericDesign: .monospaced,
        bodyDesign: .standard
    )

    /// Paloma pink, margarita lime, piña cream and Hawaiian lagoon — the one
    /// light theme, so it drives the light-surface audit.
    public static let tropicalSpritz = ThemePalette(
        id: .tropicalSpritz,
        isLight: true,
        sky: ColorToken(hex: 0xFEF7EE),
        skyRaised: ColorToken(hex: 0xFEF3E7),
        card: ColorToken(hex: 0xFDF6EC),
        cardRaised: ColorToken(hex: 0xFFFFFF),
        ink: ColorToken(hex: 0x3D2817),
        ink2: ColorToken(hex: 0x8B6F5E),
        // Deepened from a first pass at #A89080, which measured 2.75:1 on
        // cream — fainter than Night Flight's tertiary ink at 3.28:1, which is
        // the floor this app has always used.
        ink3: ColorToken(hex: 0x9A8170),
        // Deepened from the reference lagoon #7DD3C0 and hibiscus #FF6B9D.
        // The mockup uses those as *fills* with contrasting text on top
        // (--accent-foreground, --primary-foreground), but this app paints
        // accents as foreground ink in ~144 places, where the pastels land at
        // 1.65:1 and 2.52:1 on cream — effectively invisible. Same hues,
        // darkened until they clear AA on every ground.
        aurora1: ColorToken(hex: 0x0E7C6B),
        aurora2: ColorToken(hex: 0xC92D63),
        // Mango #FFA552 and margarita #A8E6A3, deepened on the same grounds.
        amber: ColorToken(hex: 0x9E5E12),
        good: ColorToken(hex: 0x1B7A2F),
        // The source palette has no negative colour — hibiscus is the primary
        // accent and can't double as an error state. A deep coral keeps the
        // tropical register while reading unmistakably as a warning.
        alert: ColorToken(hex: 0xC42B4C),
        hairline: ColorToken(hex: 0x3D2817).opacity(0.08),
        hairline2: ColorToken(hex: 0x3D2817).opacity(0.16),
        // Ink-tinted, not white: a white gloss vanishes on a cream ground.
        gloss: ColorToken(hex: 0x3D2817).opacity(0.12),
        globeOcean: ColorToken(hex: 0x7DD3C0),
        displayDesign: .serif,
        numericDesign: .rounded,
        bodyDesign: .rounded
    )

    /// Tropical Spritz on the always-black story surface.
    ///
    /// The happy accident of this theme: the reference pastels that had to be
    /// darkened for the cream app grounds — lagoon #7DD3C0, hibiscus #FF6B9D,
    /// mango #FFA552, margarita #A8E6A3 — are exactly right on black, where
    /// they clear AA comfortably. So Wrapped is the one place Tropical gets to
    /// use the design reference's actual colours.
    ///
    /// Grounds are warm near-blacks rather than neutral, so it still reads as
    /// this theme and not as Night Flight.
    public static let tropicalSpritzStory = ThemePalette(
        id: .tropicalSpritz,
        isLight: false,
        sky: ColorToken(hex: 0x0B0A09),
        skyRaised: ColorToken(hex: 0x16120E),
        card: ColorToken(hex: 0x1E1813),
        cardRaised: ColorToken(hex: 0x272019),
        // The shell cream, now serving as ink.
        ink: ColorToken(hex: 0xFEF7EE),
        ink2: ColorToken(hex: 0xD9C3AE),
        ink3: ColorToken(hex: 0xA89080),
        aurora1: ColorToken(hex: 0x7DD3C0),
        aurora2: ColorToken(hex: 0xFF6B9D),
        amber: ColorToken(hex: 0xFFA552),
        good: ColorToken(hex: 0xA8E6A3),
        alert: ColorToken(hex: 0xFB7185),
        hairline: ColorToken(hex: 0xFEF7EE).opacity(0.10),
        hairline2: ColorToken(hex: 0xFEF7EE).opacity(0.18),
        gloss: ColorToken(hex: 0xFFFFFF).opacity(0.25),
        globeOcean: ColorToken(hex: 0x7DD3C0),
        displayDesign: .serif,
        numericDesign: .rounded,
        bodyDesign: .rounded
    )

    /// Mercury × Revolut register: near-black surfaces, electric lime, and
    /// tabular numerals applied to trips instead of transactions.
    public static let mercuryDark = ThemePalette(
        id: .mercuryDark,
        isLight: false,
        sky: ColorToken(hex: 0x0A0A0B),
        skyRaised: ColorToken(hex: 0x131316),
        card: ColorToken(hex: 0x131316),
        cardRaised: ColorToken(hex: 0x1C1C22),
        ink: ColorToken(hex: 0xF4F4F5),
        ink2: ColorToken(hex: 0xF4F4F5).opacity(0.55),
        // The reference's --fin-ink-mute is 35%, which flattens to 2.82:1 on
        // near-black — below the app's tertiary floor. Lifted to 42%.
        ink3: ColorToken(hex: 0xF4F4F5).opacity(0.42),
        aurora1: ColorToken(hex: 0xC5F74F),
        aurora2: ColorToken(hex: 0xA78BFA),
        // This palette is deliberately cold. Rather than introduce an orange
        // that fights the identity, the app's one "warm note" becomes the
        // lime accent — the same role, in Mercury's own register.
        amber: ColorToken(hex: 0xC5F74F),
        good: ColorToken(hex: 0x4ADE80),
        alert: ColorToken(hex: 0xFB7185),
        hairline: ColorToken(hex: 0xFFFFFF).opacity(0.08),
        hairline2: ColorToken(hex: 0xFFFFFF).opacity(0.16),
        gloss: ColorToken(hex: 0xFFFFFF).opacity(0.18),
        globeOcean: ColorToken(hex: 0x2A2A33),
        displayDesign: .standard,
        numericDesign: .monospaced,
        bodyDesign: .standard
    )
}
