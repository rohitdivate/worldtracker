import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Location monitoring is (re)started here from M2 onward, including
        // background relaunches triggered by significant location changes
        // (launchOptions[.location]).
        true
    }
}
