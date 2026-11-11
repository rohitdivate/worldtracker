import SwiftUI
import WidgetKit

@main
struct BeenThereWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // A bundle body holds at most ten widgets, so the set is split.
        GlanceWidgets().body
        CollectionWidgets().body
    }
}

/// Where you are and how your days are adding up.
struct GlanceWidgets: WidgetBundle {
    var body: some Widget {
        YoureInWidget()
        DayLimitWidget()
        OnThisDayWidget()
        TravelGraphWidget()
        MomentumWidget()
        TravelLiveActivity()
        LimitsControl()
        PassportControl()
    }
}

/// What you've collected.
struct CollectionWidgets: WidgetBundle {
    var body: some Widget {
        CountriesWidget()
        YourTopWidget()
        YourWorldWidget()
        PassportWidget()
        ContinentsWidget()
    }
}
