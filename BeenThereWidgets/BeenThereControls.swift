import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action button controls. Each is a single
/// button that opens the app where the answer is.
struct LimitsControl: ControlWidget {
    static let kind = "BeenThereLimitsControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenBeenThereIntent(destination: .limits)) {
                Label("Day Limits", systemImage: "gauge.with.dots.needle.67percent")
            }
        }
        .displayName("Day Limits")
        .description("See how many days you have left.")
    }
}

struct PassportControl: ControlWidget {
    static let kind = "BeenTherePassportControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenBeenThereIntent(destination: .passport)) {
                Label("Passport", systemImage: "book.closed.fill")
            }
        }
        .displayName("Passport")
        .description("Open your stamps and badges.")
    }
}
