import SwiftUI
import WorldTrackerKit

/// Design tokens for the full-screen story surface.
///
/// Wrapped keeps a **black** background in every theme — a deliberate choice
/// (see `WrappedView`), the same way Instagram stories ignore app chrome. That
/// makes `Theme.*` the wrong vocabulary in here: on the light theme
/// `Theme.ink` is dark brown, which disappears on black, while `Theme.card` is
/// cream, which burns a hole in the page. Both happened.
///
/// So story views read `Story.*` instead. It resolves to the selected theme's
/// `storyPalette`, which is guaranteed dark whatever the app theme is, and is
/// contrast-tested against literal black in `ThemePaletteTests`.
///
/// **Anything rendering on the black story surface must use `Story`, not
/// `Theme`.** `Tools/validate_project.py` enforces that. Note the Wrapped
/// *share cards* are the exception and correctly use `Theme` — they render on
/// `StaticAurora`, a themed ground, not on black.
enum Story {
    static var palette: ThemePalette { ThemeStore.current.storyPalette }

    // Grounds
    static var sky: Color { palette.sky.color }
    static var skyRaised: Color { palette.skyRaised.color }
    static var card: Color { palette.card.color }
    static var cardRaised: Color { palette.cardRaised.color }

    // Ink
    static var ink: Color { palette.ink.color }
    static var ink2: Color { palette.ink2.color }
    static var ink3: Color { palette.ink3.color }

    // Accents
    static var aurora1: Color { palette.aurora1.color }
    static var aurora2: Color { palette.aurora2.color }
    static var amber: Color { palette.amber.color }

    // Semantic
    static var good: Color { palette.good.color }
    static var alert: Color { palette.alert.color }

    // Lines and overlays
    static var hairline: Color { palette.hairline.color }
    static var hairline2: Color { palette.hairline2.color }
    static var gloss: Color { palette.gloss.color }
    static var globeOcean: Color { palette.globeOcean.color }

    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [aurora1, aurora2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let cardCornerRadius: CGFloat = Theme.cardCornerRadius

    // Typography follows the theme unchanged — a typeface reads the same on
    // black as anywhere else, so only the colours needed a story variant.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: palette.displayDesign.fontDesign)
    }

    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: palette.numericDesign.fontDesign)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: palette.bodyDesign.fontDesign)
    }
}
