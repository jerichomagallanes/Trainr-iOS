import FirebaseCrashlytics

// One implementation for every build rather than a no-op for development:
// collection is switched off at launch in debug builds, so every development run
// still exercises this code.
struct CrashlyticsBreadcrumbs: Breadcrumbs {

    func record(_ event: String) {
        Crashlytics.crashlytics().log(event)
    }

    func state(key: String, value: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    // A non-fatal, logged first so the failure reads in order with the trail.
    func report(_ error: any Error, doing action: String) {
        Crashlytics.crashlytics().log("failed: \(action)")
        Crashlytics.crashlytics().record(error: error, userInfo: ["action": action])
    }
}
