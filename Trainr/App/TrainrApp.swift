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

    // Guarded on the config file so a checkout without Firebase credentials
    // still builds, runs and generates with the canned coach; the file is not
    // committed, because it names the project the shipped app talks to.
    private static func configureFirebase() {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
        else { return }
        AppCheck.setAppCheckProviderFactory(TrainrAppCheckProviderFactory())
        FirebaseApp.configure()
        #if DEBUG
        // A developer's own crashes are noise in the report that watches the
        // shipped app, so debug runs record breadcrumbs into the void.
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
    }
}

// Every request to Firebase carries a token proving it came from this app on a
// genuine device. Debug builds use the debug provider — a token minted locally
// and registered by hand in the Firebase console — because App Attest only
// exists on real devices.
final class TrainrAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        AppCheckDebugProvider(app: app)
        #else
        AppAttestProvider(app: app)
        #endif
    }
}
