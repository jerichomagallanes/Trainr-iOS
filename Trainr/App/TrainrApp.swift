import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import SwiftUI

@main
struct TrainrApp: App {

    init() {
        Self.configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    // Guarded so a checkout without the uncommitted Firebase config still runs.
    private static func configureFirebase() {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
        else { return }
        AppCheck.setAppCheckProviderFactory(TrainrAppCheckProviderFactory())
        FirebaseApp.configure()
        #if DEBUG
        // A developer's own crashes are noise in the shipped app's report.
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
    }
}

// App Attest exists only on real devices, so debug builds use a locally minted
// token registered by hand in the Firebase console.
final class TrainrAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        AppCheckDebugProvider(app: app)
        #else
        AppAttestProvider(app: app)
        #endif
    }
}
