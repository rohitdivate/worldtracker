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

    /// Secondary and tertiary ink are allowed to be quieter, but not
    /// illegible — 3:1 is the floor, matching Night Flight's long-standing
    /// tertiary at 3.28:1.
    ///
    /// Both ramps are alpha-based in at least one palette, so this only means
    /// anything because `contrastRatio` composites before measuring. Measured
    /// as opaque, Mercury's 35% tertiary scored 19:1 while actually rendering
    /// at 2.8:1.
    func testSecondaryAndTertiaryInkStayLegible() {
        for id in ThemeID.allCases {
            for (label, palette) in [("app", id.palette), ("story", id.storyPalette)] {
                let ground = label == "story" ? ColorToken(hex: 0x000000) : palette.sky
                for (name, ink) in [("ink2", palette.ink2), ("ink3", palette.ink3)] {
                    let ratio = ink.contrastRatio(against: ground)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 3.0,
                        "\(id) \(label): \(name) is \(String(format: "%.2f", ratio)):1, below 3.0"
                    )
                }
            }
        }
    }

    /// The ink ramp has to actually descend, or ink2/ink3 are pointless.
    func testInkRampDescends() {
        for id in ThemeID.allCases {
            let p = id.palette
            let ink = p.ink.contrastRatio(against: p.sky)
            let ink2 = p.ink2.contrastRatio(against: p.sky)
            let ink3 = p.ink3.contrastRatio(against: p.sky)
            XCTAssertGreaterThan(ink, ink2, "\(id): ink should be stronger than ink2")
            XCTAssertGreaterThan(ink2, ink3, "\(id): ink2 should be stronger than ink3")
        }
    }

    /// Compositing is the whole reason the legibility tests mean anything.
    func testTranslucentForegroundIsCompositedBeforeMeasuring() {
        let black = ColorToken(hex: 0x000000)
        let faintWhite = ColorToken(hex: 0xFFFFFF).opacity(0.35)
        // Opaque white on black is the 21:1 maximum; at 35% it is far less.
        XCTAssertEqual(ColorToken(hex: 0xFFFFFF).contrastRatio(against: black), 21.0, accuracy: 0.01)
        XCTAssertLessThan(
            faintWhite.contrastRatio(against: black), 6.0,
            "a 35% foreground must not measure like an opaque one"
        )
        // Compositing an opaque colour is a no-op.
        XCTAssertEqual(ColorToken(hex: 0x59E3C8).composited(over: black), ColorToken(hex: 0x59E3C8))
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

    // MARK: - Story palettes
    //
    // Wrapped keeps a black background in every theme, so its content is
    // measured against literal black — not against the theme's own ground.
    // Missing this is what made Tropical Spritz's Wrapped unreadable: dark
    // brown ink on black, next to cream cards on black.

    private let storyGround = ColorToken(hex: 0x000000)

    func testStoryPalettesAreAlwaysDark() {
        for id in ThemeID.allCases {
            XCTAssertFalse(
                id.storyPalette.isLight,
                "\(id): story palette must be dark — it renders on black"
            )
        }
    }

    func testStoryInkAndAccentsClearAAOnBlack() {
        for id in ThemeID.allCases {
            let p = id.storyPalette
            let critical = [
                ("ink", p.ink), ("aurora1", p.aurora1),
                ("aurora2", p.aurora2), ("amber", p.amber),
            ]
            for (name, colour) in critical {
                let ratio = colour.contrastRatio(against: storyGround)
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5,
                    "\(id) story: \(name) on black is \(String(format: "%.2f", ratio)):1, below AA 4.5"
                )
            }
            // Secondary ink is quieter but still has to be readable.
            for (name, colour) in [("ink2", p.ink2), ("ink3", p.ink3)] {
                let ratio = colour.contrastRatio(against: storyGround)
                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0,
                    "\(id) story: \(name) on black is \(String(format: "%.2f", ratio)):1, below 3.0"
                )
            }
        }
    }

    /// Cards sit on black and must be distinguishable from it without
    /// glaring — the failure mode where a light theme's cream card burns a
    /// hole in the story.
    func testStoryCardsSitCloseToBlack() {
        for id in ThemeID.allCases {
            let p = id.storyPalette
            for (name, ground) in [("card", p.card), ("cardRaised", p.cardRaised), ("sky", p.sky)] {
                let ratio = ground.contrastRatio(against: storyGround)
                XCTAssertLessThan(
                    ratio, 3.0,
                    "\(id) story: \(name) is \(String(format: "%.2f", ratio)):1 against black — too bright for a story surface"
                )
            }
        }
    }

    /// Dark themes need no separate story palette; a divergence would mean
    /// two definitions to keep in step for no benefit.
    func testDarkThemesReuseTheirOwnPaletteForStories() {
        for id in ThemeID.allCases where !id.palette.isLight {
            XCTAssertEqual(
                id.storyPalette.sky, id.palette.sky,
                "\(id) is already dark — its story palette should be the same palette"
            )
        }
    }

    /// The point of the light theme's story variant: it gets to use the
    /// design reference's real pastels, which only work on black.
    func testTropicalStoryUsesTheReferencePastels() {
        let story = ThemeID.tropicalSpritz.storyPalette
        XCTAssertEqual(story.aurora1, ColorToken(hex: 0x7DD3C0), "lagoon")
        XCTAssertEqual(story.aurora2, ColorToken(hex: 0xFF6B9D), "hibiscus")
        XCTAssertEqual(story.amber, ColorToken(hex: 0xFFA552), "mango")
        XCTAssertEqual(story.good, ColorToken(hex: 0xA8E6A3), "margarita")
        // And it stays recognisably this theme rather than becoming Night Flight.
        XCTAssertNotEqual(story.sky, ThemePalette.nightFlight.sky)
        XCTAssertEqual(story.displayDesign, ThemeID.tropicalSpritz.palette.displayDesign)
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
