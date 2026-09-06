import FirebaseCrashlytics

// Written straight onto the next crash report.
//
// One implementation for every build rather than a no-op for development:
// collection is switched off at launch in debug builds, so recording there
// costs nothing and goes nowhere, and every development run still exercises
// this code. A breadcrumb that only runs in the shipped build is a breadcrumb
// nobody has ever seen work.
struct CrashlyticsBreadcrumbs: Breadcrumbs {

    func record(_ event: String) {
        Crashlytics.crashlytics().log(event)
    }

    func state(key: String, value: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    // A non-fatal: it arrives in the console like a crash, with the trail so
    // far, but the session goes on. The action goes in the trail too, so the
    // failures read in order with everything else.
    func report(_ error: any Error, doing action: String) {
        Crashlytics.crashlytics().log("failed: \(action)")
        Crashlytics.crashlytics().record(error: error, userInfo: ["action": action])
    }
}
