import XCTest
@testable import WorldTrackerKit

/// The app target can't be compiled off a Mac, so these tests are the only
/// automated signal that a palette is well-formed before macOS CI runs.
final class ThemePaletteTests: XCTestCase {

    /// Every token of every palette, so new tokens are covered without the
    /// tests having to be updated in two places.
    private func allTokens(_ p: ThemePalette) -> [(String, ColorToken)] {
        [
            ("sky", p.sky), ("skyRaised", p.skyRaised),
            ("card", p.card), ("cardRaised", p.cardRaised),
            ("ink", p.ink), ("ink2", p.ink2), ("ink3", p.ink3),
            ("aurora1", p.aurora1), ("aurora2", p.aurora2), ("amber", p.amber),
            ("good", p.good), ("alert", p.alert),
            ("hairline", p.hairline), ("hairline2", p.hairline2),
            ("gloss", p.gloss), ("globeOcean", p.globeOcean),
        ]
    }

    func testEveryThemeResolvesToItsOwnPalette() {
        for id in ThemeID.allCases {
            XCTAssertEqual(ThemePalette.palette(for: id).id, id, "\(id) resolved to the wrong palette")
        }
        XCTAssertEqual(ThemeID.allCases.count, 3)
    }

    func testComponentsAreInRange() {
        for id in ThemeID.allCases {
            for (name, token) in allTokens(id.palette) {
                for (channel, value) in [
                    ("red", token.red), ("green", token.green),
                    ("blue", token.blue), ("alpha", token.alpha),
                ] {
                    XCTAssertTrue(
                        (0...1).contains(value),
                        "\(id).\(name).\(channel) = \(value) is outside 0…1"
                    )
                }
            }
        }
    }

    /// Body text on the app's base ground has to be readable in every theme.
    /// This is the check that would have caught a light palette keeping the
    /// old near-white ink.
    func testPrimaryInkClearsWCAGAAOnEveryGround() {
        for id in ThemeID.allCases {
            let p = id.palette
            for (name, ground) in [("sky", p.sky), ("skyRaised", p.skyRaised), ("card", p.card)] {
                let ratio = p.ink.contrastRatio(against: ground)
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5,
                    "\(id): ink on \(name) is \(String(format: "%.2f", ratio)):1, below WCAG AA 4.5"
                )
            }
        }
    }

    /// Secondary ink is allowed to be quieter, but not illegible — AA large
    /// text (3:1) is the floor, since it's used at small-but-not-tiny sizes.
    func testSecondaryInkStaysLegible() {
        for id in ThemeID.allCases {
            let p = id.palette
            let ratio = p.ink2.contrastRatio(against: p.sky)
            XCTAssertGreaterThanOrEqual(
                ratio, 3.0,
                "\(id): ink2 on sky is \(String(format: "%.2f", ratio)):1, below 3.0"
            )
        }
    }

    /// A light theme with a dark ground (or vice versa) means `isLight` is
    /// lying, and `preferredColorScheme` would fight the palette.
    func testIsLightMatchesTheActualGround() {
        for id in ThemeID.allCases {
            let p = id.palette
            if p.isLight {
                XCTAssertGreaterThan(p.sky.luminance, 0.5, "\(id) claims isLight but sky is dark")
            } else {
                XCTAssertLessThan(p.sky.luminance, 0.5, "\(id) claims dark but sky is light")
            }
        }
    }

    /// Accents have to be distinguishable from each other and from the ground,
    /// or the aurora gradient collapses into a flat wash.
    func testAccentsAreDistinct() {
        for id in ThemeID.allCases {
            XCTAssertNotEqual(
                id.palette.aurora1, id.palette.aurora2,
                "\(id): aurora1 and aurora2 are identical"
            )
        }
    }

    /// The app paints accents and semantic colours as foreground ink, not as
    /// fills, so they carry the same AA burden as body text. This is the test
    /// that caught Tropical Spritz's pastel lagoon at 1.65:1 on cream.
    func testForegroundColoursClearWCAGAA() {
        for id in ThemeID.allCases {
            let p = id.palette
            let foregrounds = [
                ("aurora1", p.aurora1), ("aurora2", p.aurora2), ("amber", p.amber),
                ("good", p.good), ("alert", p.alert),
            ]
            for (name, colour) in foregrounds {
                for (ground, bg) in [("sky", p.sky), ("skyRaised", p.skyRaised), ("card", p.card)] {
                    let ratio = colour.contrastRatio(against: bg)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        "\(id): \(name) on \(ground) is \(String(format: "%.2f", ratio)):1, below AA 4.5"
                    )
                }
            }
        }
    }

    /// Hairlines and gloss are overlays — fully opaque ones would paint over
    /// content instead of hinting at an edge.
    func testOverlayTokensAreTranslucent() {
        for id in ThemeID.allCases {
            let p = id.palette
            for (name, token) in [("hairline", p.hairline), ("hairline2", p.hairline2), ("gloss", p.gloss)] {
                XCTAssertLessThan(token.alpha, 1.0, "\(id).\(name) is opaque")
                XCTAssertGreaterThan(token.alpha, 0.0, "\(id).\(name) is fully transparent")
            }
            XCTAssertLessThan(
                p.hairline.alpha, p.hairline2.alpha,
                "\(id): hairline2 should be the stronger of the two"
            )
        }
    }

    /// Night Flight is the default and must be pixel-identical to the values
    /// that were compiled in before themes existed. If this fails, existing
    /// users' app changed appearance — which the whole change promised not to.
    func testNightFlightMatchesThePreThemeConstants() {
        let p = ThemePalette.nightFlight
        XCTAssertEqual(p.sky, ColorToken(hex: 0x070B16))
        XCTAssertEqual(p.skyRaised, ColorToken(hex: 0x0C1322))
        XCTAssertEqual(p.card, ColorToken(hex: 0x131C31))
        XCTAssertEqual(p.cardRaised, ColorToken(hex: 0x151F38))
        XCTAssertEqual(p.ink, ColorToken(hex: 0xEDF2FF))
        XCTAssertEqual(p.ink2, ColorToken(hex: 0x8E9BC0))
        XCTAssertEqual(p.ink3, ColorToken(hex: 0x55628A))
        XCTAssertEqual(p.aurora1, ColorToken(hex: 0x59E3C8))
        XCTAssertEqual(p.aurora2, ColorToken(hex: 0x7B8CFF))
        XCTAssertEqual(p.amber, ColorToken(hex: 0xFFB74D))
        XCTAssertEqual(p.good, ColorToken(hex: 0x4ADE80))
        XCTAssertEqual(p.alert, ColorToken(hex: 0xF87171))
        XCTAssertEqual(ThemeID.default, .nightFlight)
    }

    func testUnknownStoredValueFallsBackToDefault() {
        XCTAssertEqual(ThemeID(storedValue: nil), .nightFlight)
        XCTAssertEqual(ThemeID(storedValue: ""), .nightFlight)
        XCTAssertEqual(ThemeID(storedValue: "someRemovedTheme"), .nightFlight)
        XCTAssertEqual(ThemeID(storedValue: "mercuryDark"), .mercuryDark)
    }

    /// Raw values are persisted and shared with the widget; renaming one
    /// silently resets everyone's choice.
    func testRawValuesAreStable() {
        XCTAssertEqual(ThemeID.nightFlight.rawValue, "nightFlight")
        XCTAssertEqual(ThemeID.tropicalSpritz.rawValue, "tropicalSpritz")
        XCTAssertEqual(ThemeID.mercuryDark.rawValue, "mercuryDark")
    }

    func testEveryThemeHasDisplayTextForSettings() {
        for id in ThemeID.allCases {
            XCTAssertFalse(id.displayName.isEmpty, "\(id) has no display name")
            XCTAssertFalse(id.tagline.isEmpty, "\(id) has no tagline")
        }
    }

    func testHexAndOpacityHelpers() {
        let white = ColorToken(hex: 0xFFFFFF)
        XCTAssertEqual(white.red, 1.0, accuracy: 0.0001)
        XCTAssertEqual(white.green, 1.0, accuracy: 0.0001)
        XCTAssertEqual(white.blue, 1.0, accuracy: 0.0001)
        XCTAssertEqual(white.alpha, 1.0, accuracy: 0.0001)

        let black = ColorToken(hex: 0x000000)
        // The canonical extremes: white on black is the maximum 21:1.
        XCTAssertEqual(white.contrastRatio(against: black), 21.0, accuracy: 0.01)
        XCTAssertEqual(white.contrastRatio(against: white), 1.0, accuracy: 0.01)

        XCTAssertEqual(white.opacity(0.25).alpha, 0.25, accuracy: 0.0001)
        XCTAssertEqual(white.opacity(0.25).red, 1.0, accuracy: 0.0001)

        let mid = ColorToken(hex: 0x8E9BC0)
        XCTAssertEqual(mid.red, 142.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(mid.green, 155.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(mid.blue, 192.0 / 255.0, accuracy: 0.0001)
    }
}
