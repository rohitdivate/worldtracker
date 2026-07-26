import SwiftUI
import WorldTrackerKit

/// Design tokens for the widget target.
///
/// Previously a hand-copied duplicate of the app's Night Flight constants.
/// Both targets now read one palette definition from
/// `WorldTrackerKit/Design/ThemePalettes.swift`, so a theme can't drift
/// between the app and its widgets.
///
/// Tokens are computed rather than stored: widget timelines are rendered
/// fresh in a separate process, so each render picks up whatever theme the app
/// last wrote to the App Group.
enum WTheme {
    /// Read per access, not cached — the widget process is short-lived and
    /// may outlive a theme change the app made in between renders.
    static var palette: ThemePalette { WidgetThemeReader.current.palette }

    static var sky: Color { palette.sky.color }
    static var skyRaised: Color { palette.skyRaised.color }
    static var card: Color { palette.card.color }
    static var ink: Color { palette.ink.color }
    static var ink2: Color { palette.ink2.color }
    static var ink3: Color { palette.ink3.color }
    static var aurora1: Color { palette.aurora1.color }
    static var aurora2: Color { palette.aurora2.color }
    static var amber: Color { palette.amber.color }

    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [aurora1, aurora2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Tiny identity mark for widget corners — a stranger glancing at a
    /// lock screen or home screen should be able to find the app.
    struct Wordmark: View {
        var body: some View {
            Text("BEEN THERE")
                .font(.system(
                    size: 6.5,
                    weight: .heavy,
                    design: WTheme.palette.numericDesign.fontDesign
                ))
                .tracking(1.6)
                .foregroundStyle(WTheme.ink3)
        }
    }

    /// The widget canvas: the theme's ground with a whisper of accent in the
    /// corner.
    static var background: some View {
        LinearGradient(
            colors: [skyRaised, sky],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [aurora2.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 90
                    )
                )
                .frame(width: 160, height: 160)
                .offset(x: 50, y: -50)
        }
    }
}

/// Reads the theme the app selected, out of the shared App Group.
enum WidgetThemeReader {
    /// Falls back to the default theme when the App Group isn't in this
    /// build's signing — same degradation as `WidgetSnapshotReader`, so an
    /// unthemed widget is a missing capability rather than a crash.
    static var current: ThemeID {
        let defaults = UserDefaults(suiteName: WidgetSnapshotReader.appGroupID)
        return ThemeID(storedValue: defaults?.string(forKey: "themeID"))
    }
}

// MARK: - Kit token → SwiftUI bridging

extension ColorToken {
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
