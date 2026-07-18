import SwiftUI

/// Night Flight tokens, duplicated for the widget target — the app's
/// DesignSystem lives in the app target only, and widgets should stay lean.
enum WTheme {
    static let sky = Color(red: 0.027, green: 0.043, blue: 0.086)        // #070B16
    static let skyRaised = Color(red: 0.047, green: 0.075, blue: 0.133)  // #0C1322
    static let card = Color(red: 0.075, green: 0.110, blue: 0.192)       // #131C31
    static let ink = Color(red: 0.930, green: 0.949, blue: 1.0)          // #EDF2FF
    static let ink2 = Color(red: 0.557, green: 0.608, blue: 0.753)       // #8E9BC0
    static let ink3 = Color(red: 0.333, green: 0.384, blue: 0.541)       // #55628A
    static let aurora1 = Color(red: 0.349, green: 0.890, blue: 0.784)    // #59E3C8
    static let aurora2 = Color(red: 0.482, green: 0.549, blue: 1.0)      // #7B8CFF
    static let amber = Color(red: 1.0, green: 0.718, blue: 0.302)        // #FFB74D

    static let auroraGradient = LinearGradient(
        colors: [aurora1, aurora2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The widget canvas: deep sky with a whisper of aurora in the corner.
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
