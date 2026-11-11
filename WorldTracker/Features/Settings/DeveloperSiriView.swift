import SwiftUI
import WorldTrackerKit

/// The exact sentences the Siri shortcuts would speak right now, from live
/// data. Exists because App Shortcuts cannot be executed on the iOS 26.5
/// simulator (FB23504349); this is how the answers get checked there.
struct DeveloperSiriView: View {
    private var store: LedgerStore { AppContainer.shared.ledgerStore }

    var body: some View {
        let _ = store.changeToken
        let top = AppContainer.shared.insightsStore.summary(using: store).stamps
            .sorted { ($0.totalDays, $1.code) > ($1.totalDays, $0.code) }
            .prefix(3)
        List {
            Group {
            Section("Where Am I") {
                Text(SiriAnswers.whereAmI())
            }
            Section("Check Day Limits") {
                Text(SiriAnswers.dayLimits())
            }
            Section("Days in a Country") {
                ForEach(Array(top), id: \.code) { stamp in
                    Text(SiriAnswers.days(in: stamp.code))
                }
                Text(SiriAnswers.days(in: "AQ"))
            }
            }
            .listRowBackground(Theme.card)
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.ink)
        .themedList()
        .navigationTitle(Theme.title("Siri answers"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
