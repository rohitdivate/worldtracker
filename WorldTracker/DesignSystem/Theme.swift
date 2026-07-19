import SwiftUI

/// Night Flight design tokens.
/// Deep indigo grounds, aurora teal→violet accents, one warm amber note.
enum Theme {
    // Grounds
    static let sky = Color(red: 0.027, green: 0.043, blue: 0.086)        // #070B16
    static let skyRaised = Color(red: 0.047, green: 0.075, blue: 0.133)  // #0C1322
    static let card = Color(red: 0.075, green: 0.110, blue: 0.192)       // #131C31
    static let cardRaised = Color(red: 0.082, green: 0.122, blue: 0.220) // #151F38

    // Ink
    static let ink = Color(red: 0.930, green: 0.949, blue: 1.0)          // #EDF2FF
    static let ink2 = Color(red: 0.557, green: 0.608, blue: 0.753)       // #8E9BC0
    static let ink3 = Color(red: 0.333, green: 0.384, blue: 0.541)       // #55628A

    // Accents
    static let aurora1 = Color(red: 0.349, green: 0.890, blue: 0.784)    // #59E3C8
    static let aurora2 = Color(red: 0.482, green: 0.549, blue: 1.0)      // #7B8CFF
    static let amber = Color(red: 1.0, green: 0.718, blue: 0.302)        // #FFB74D

    // Semantic
    static let good = Color(red: 0.290, green: 0.871, blue: 0.502)       // #4ADE80
    static let alert = Color(red: 0.973, green: 0.443, blue: 0.443)      // #F87171

    static let auroraGradient = LinearGradient(
        colors: [aurora1, aurora2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hairline = Color(red: 0.616, green: 0.698, blue: 1.0).opacity(0.10)
    static let hairline2 = Color(red: 0.616, green: 0.698, blue: 1.0).opacity(0.18)

    static let cardCornerRadius: CGFloat = 20
}

extension View {
    /// Standard Night Flight card surface.
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
