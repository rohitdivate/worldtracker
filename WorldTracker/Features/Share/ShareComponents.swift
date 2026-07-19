import SwiftUI

/// Shared pieces of every share card. All static-render safe: one
/// deterministic aurora frame, no TimelineView, no lazy containers.

/// One deterministic aurora frame — ImageRenderer never sees a TimelineView.
struct StaticAurora: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.38, 0.32], [1, 0.5],
                [0, 1], [0.7, 0.6], [1, 1],
            ],
            colors: [
                Theme.sky, Theme.skyRaised, Theme.sky,
                Theme.skyRaised,
                Theme.aurora1.opacity(0.30),
                Theme.aurora2.opacity(0.28),
                Theme.sky, Theme.skyRaised, Theme.sky,
            ]
        )
    }
}

/// The identity mark on every card. `withHook` adds the acquisition line —
/// a stranger seeing the card should know where to get the app.
struct ShareWordmark: View {
    var withHook = false

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 7) {
                MiniGlobe(size: 16, showsPlane: false)
                Text("BEEN THERE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.ink2)
            }
            if withHook {
                Text(hookLine)
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private var hookLine: String {
        AppLinks.appStoreShortURL.isEmpty
            ? "FOR iPHONE"
            : "FOR iPHONE · \(AppLinks.appStoreShortURL)"
    }
}

struct ShareStat: View {
    let value: String
    let label: String
    var color: Color = Theme.aurora1

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
    }
}
