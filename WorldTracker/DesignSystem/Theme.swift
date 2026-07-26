import SwiftUI
import WidgetKit
import WorldTrackerKit

/// Design tokens for the selected theme.
///
/// These used to be `static let` constants for the single Night Flight
/// identity. They're now computed over `Theme.palette`, which means all ~619
/// `Theme.x` call sites keep working untouched — the theme changes underneath
/// them. Palette *data* lives in `WorldTrackerKit/Design/ThemePalettes.swift`
/// so the widget shares one definition and the values stay testable on Linux.
enum Theme {
    /// The active palette. Set once at launch and again on each switch, via
    /// `ThemeStore.select(_:)` — never assign this directly, or the widget and
    /// persisted choice drift out of step.
    static var palette: ThemePalette = ThemeStore.currentPalette()

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
    /// Chip rings and gloss highlights. Was a bare `Color.white` before
    /// themes — invisible on a light ground.
    static var gloss: Color { palette.gloss.color }
    static var globeOcean: Color { palette.globeOcean.color }

    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [aurora1, aurora2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let cardCornerRadius: CGFloat = 20

    // MARK: - Typography
    //
    // Applied to identity-carrying surfaces only (big numbers, headers, the
    // wordmark), not to all 400-odd font call sites. Night Flight's values
    // reproduce what those surfaces already used, so the default theme is
    // unchanged.

    /// Headline and hero text.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: palette.displayDesign.fontDesign)
    }

    /// Counters and stats — the numerals that carry a theme's precision.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: palette.numericDesign.fontDesign)
    }

    /// Body copy on themed surfaces.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: palette.bodyDesign.fontDesign)
    }
}

// MARK: - Kit token → SwiftUI bridging

extension ColorToken {
    /// `.sRGB` explicitly: the palettes are authored as sRGB hex values, and
    /// SwiftUI's default `Color(red:green:blue:)` is also sRGB, so this keeps
    /// Night Flight byte-identical to the old constants.
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension FontDesignToken {
    var fontDesign: Font.Design {
        switch self {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

// MARK: - Selection

/// Reads and writes the chosen theme. The single mutation point, so the
/// in-memory palette, the persisted value and the widgets can't disagree.
enum ThemeStore {
    /// Also read by `@AppStorage` in `WorldTrackerApp` and by the widget
    /// target through the App Group — changing it resets everyone's choice.
    static let key = "themeID"

    static var current: ThemeID {
        ThemeID(storedValue: UserDefaults.standard.string(forKey: key))
    }

    static func currentPalette() -> ThemePalette { current.palette }

    /// Persist, mirror to the widgets, and swap the live palette.
    static func select(_ id: ThemeID) {
        UserDefaults.standard.set(id.rawValue, forKey: key)
        // The widget process can't see the app's standard defaults.
        UserDefaults(suiteName: SharedSnapshotStore.appGroupID)?
            .set(id.rawValue, forKey: key)
        paletteDidChange(to: id)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Keeps `Theme.palette` in step with a value that changed elsewhere —
    /// e.g. `@AppStorage` writing before this type is consulted.
    static func paletteDidChange(to id: ThemeID) {
        Theme.palette = id.palette
    }
}

extension View {
    /// Standard themed card surface. Still named `nightCard()` because ~20
    /// call sites use it and renaming would be churn for no behaviour change.
    func nightCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.cardRaised, Theme.card],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }
}
