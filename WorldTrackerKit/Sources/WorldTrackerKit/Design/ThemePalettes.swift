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

    /// WCAG contrast ratio against another colour, 1…21. Alpha is ignored —
    /// callers compare opaque grounds against opaque ink.
    public func contrastRatio(against other: ColorToken) -> Double {
        let a = luminance + 0.05
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
}

/// The themes a user can pick. Raw values are persisted in UserDefaults and
/// shared with the widget through the App Group — don't rename them.
public enum ThemeID: String, CaseIterable, Identifiable, Sendable {
    case nightFlight
    case tropicalSpritz
    case mercuryDark

    public var id: String { rawValue }

    /// Falls back rather than failing: an unknown stored value (older build,
    /// hand-edited defaults) should look like the default theme, not crash.
    public init(storedValue: String?) {
        self = ThemeID(rawValue: storedValue ?? "") ?? .nightFlight
    }

    public static var `default`: ThemeID { .nightFlight }

    public var displayName: String {
        switch self {
        case .nightFlight: "Night Flight"
        case .tropicalSpritz: "Tropical Spritz"
        case .mercuryDark: "Mercury Dark"
        }
    }

    /// One line for the Settings row — what the theme feels like, not a colour list.
    public var tagline: String {
        switch self {
        case .nightFlight: "Deep indigo and aurora. The original."
        case .tropicalSpritz: "Warm cream, hibiscus and lagoon. Light."
        case .mercuryDark: "Near-black surfaces, electric lime, mono numerals."
        }
    }

    public var palette: ThemePalette { ThemePalette.palette(for: self) }
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

    public static func palette(for id: ThemeID) -> ThemePalette {
        switch id {
        case .nightFlight: nightFlight
        case .tropicalSpritz: tropicalSpritz
        case .mercuryDark: mercuryDark
        }
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
        ink3: ColorToken(hex: 0xA89080),
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
        ink3: ColorToken(hex: 0xF4F4F5).opacity(0.35),
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
