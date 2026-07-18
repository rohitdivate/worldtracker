import CoreHaptics
import UIKit

/// One place that speaks haptics. CoreHaptics when the hardware has it,
/// UIFeedbackGenerator otherwise — callers never care which.
@MainActor
final class HapticsDirector {
    static let shared = HapticsDirector()

    private var engine: CHHapticEngine?
    private var engineRunning = false

    private init() {}

    /// Light touch — page turns, small confirmations.
    func tick() {
        play([transient(intensity: 0.45, sharpness: 0.55, at: 0)], fallback: .light)
    }

    /// The passport stamp: a hard hit and its echo.
    func stampSlam() {
        play(
            [
                transient(intensity: 1.0, sharpness: 0.9, at: 0),
                transient(intensity: 0.6, sharpness: 0.4, at: 0.09),
            ],
            fallback: .rigid
        )
    }

    /// Milestone landed — rising triple.
    func celebrate() {
        play(
            [
                transient(intensity: 0.5, sharpness: 0.4, at: 0),
                transient(intensity: 0.75, sharpness: 0.6, at: 0.12),
                transient(intensity: 1.0, sharpness: 0.9, at: 0.26),
            ],
            fallback: .heavy
        )
    }

    // MARK: - Plumbing

    private func transient(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func play(_ events: [CHHapticEvent], fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        if let engine = runningEngine(),
           let pattern = try? CHHapticPattern(events: events, parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            do {
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                engineRunning = false
            }
        }
        UIImpactFeedbackGenerator(style: fallback).impactOccurred()
    }

    private func runningEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        if let engine, engineRunning { return engine }
        do {
            let fresh = try engine ?? CHHapticEngine()
            fresh.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engineRunning = false }
            }
            fresh.resetHandler = { [weak self] in
                Task { @MainActor in self?.engineRunning = false }
            }
            try fresh.start()
            engine = fresh
            engineRunning = true
            return fresh
        } catch {
            return nil
        }
    }
}
