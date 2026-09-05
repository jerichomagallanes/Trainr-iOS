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
}
