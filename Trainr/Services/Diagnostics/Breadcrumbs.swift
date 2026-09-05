// The trail a crash report carries: what the app was doing just before it fell
// over. A stack trace says which line broke; this says how the client got there.
//
// Deliberately narrow. Only events and app state go in here — never a name, an
// age, a weight or an injury. A crash report is read by whoever is debugging,
// stored by Google, and outlives the session, so the profile has no business in
// one. The policy promises that crash reports "say what broke, not who you are",
// and this protocol is where that promise is either kept or broken.
protocol Breadcrumbs {

    // Something happened, in the order it happened.
    func record(_ event: String)

    // A fact that is true until it changes, attached to whatever crash follows.
    func state(key: String, value: String)
}

// For tests, and for anywhere a trail would be noise.
struct NoBreadcrumbs: Breadcrumbs {
    func record(_ event: String) {}
    func state(key: String, value: String) {}
}
