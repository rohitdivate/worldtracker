import SwiftUI

/// Transient-only shader application. While idle these modifiers are
/// structural no-ops (the shader isn't even in the view tree), so a broken
/// or missing Metal function can never wedge the UI — the worst case is
/// simply "no flourish".

// MARK: - Ripple (calendar tap)

extension View {
    /// Fires a touch ripple from `origin` (local points) each time
    /// `trigger` changes.
    func rippleEffect(at origin: CGPoint, trigger: Int) -> some View {
        modifier(RippleContainer(origin: origin, trigger: trigger))
    }
}

private struct RippleContainer: ViewModifier {
    let origin: CGPoint
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    private let duration: TimeInterval = 0.7

    func body(content: Content) -> some View {
        Group {
            if let start, !reduceMotion {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    content
                        .modifier(RippleShader(origin: origin, elapsed: min(elapsed, duration)))
                        .onChange(of: elapsed > duration) { _, done in
                            if done { self.start = nil }
                        }
                }
            } else {
                content
            }
        }
        .onChange(of: trigger) { _, _ in
            start = Date()
        }
    }
}

private struct RippleShader: ViewModifier {
    let origin: CGPoint
    let elapsed: TimeInterval

    func body(content: Content) -> some View {
        content.distortionEffect(
            ShaderLibrary.ripple(
                .float2(origin),
                .float(elapsed),
                .float(10),    // amplitude (pt)
                .float(14),    // frequency
                .float(7),     // decay
                .float(1600)   // wavefront speed (pt/s)
            ),
            maxSampleOffset: CGSize(width: 10, height: 10)
        )
    }
}

// MARK: - Shine (closer card)

extension View {
    /// A highlight band sweeps the view as `progress` runs 0→1.
    /// Outside that window the shader is detached entirely.
    func shineEffect(progress: Double) -> some View {
        modifier(ShineContainer(progress: progress))
    }
}

private struct ShineContainer: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        Group {
            if progress > 0, progress < 1 {
                content.visualEffect { view, proxy in
                    view.colorEffect(
                        ShaderLibrary.shine(
                            .float2(proxy.size),
                            // Overdrive past the edges so the band fully
                            // enters and exits.
                            .float(-0.2 + 1.4 * progress)
                        )
                    )
                }
            } else {
                content
            }
        }
    }
}
