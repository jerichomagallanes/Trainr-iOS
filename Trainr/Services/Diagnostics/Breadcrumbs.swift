// The trail a crash report carries. Deliberately narrow: only events and app
// state go in here, never a name, an age, a weight or an injury. A crash report
// is stored by Google and outlives the session.
protocol Breadcrumbs {

    func record(_ event: String)

    // `action` names what was being attempted, never what it was attempted on.
    func report(_ error: any Error, doing action: String)
}

struct NoBreadcrumbs: Breadcrumbs {
    func record(_ event: String) {}
    func report(_ error: any Error, doing action: String) {}
}
