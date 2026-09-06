import Foundation
import Testing
@testable import Trainr

@Suite("Attempting a store call")
struct AppDependenciesTests {

    private final class RecordingBreadcrumbs: Breadcrumbs {
        var events: [String] = []
        var reported: [(String, String)] = []
        func record(_ event: String) { events.append(event) }
        func state(key: String, value: String) {}
        func report(_ error: any Error, doing action: String) {
            reported.append((action, String(describing: error)))
        }
    }

    private struct Refused: Error {}

    private func dependencies(_ breadcrumbs: RecordingBreadcrumbs) throws -> AppDependencies {
        AppDependencies(
            store: TrainingStore(container: try TrainingStore.container(inMemory: true)),
            planGenerator: CannedPlanGenerator(),
            breadcrumbs: breadcrumbs
        )
    }

    @Test("A call that succeeds hands back its value and reports nothing")
    func successPassesThrough() throws {
        let crumbs = RecordingBreadcrumbs()
        let value = try dependencies(crumbs).attempt("count", { 3 })
        #expect(value == 3)
        #expect(crumbs.reported.isEmpty)
    }

    @Test("A call that throws is reported by what it was doing, and yields nothing")
    func failureIsReported() throws {
        let crumbs = RecordingBreadcrumbs()
        let value: Int? = try dependencies(crumbs).attempt("updateDay", { throw Refused() })
        #expect(value == nil)
        #expect(crumbs.reported.count == 1)
        #expect(crumbs.reported.first?.0 == "updateDay")
    }

    @Test("An optional-returning call is flattened, so nil and failure read alike")
    func optionalIsFlattened() throws {
        let crumbs = RecordingBreadcrumbs()
        let deps = try dependencies(crumbs)
        let absent: Int? = deps.attempt("lookup", { () throws -> Int? in nil })
        let present: Int? = deps.attempt("lookup", { () throws -> Int? in 7 })
        #expect(absent == nil)
        #expect(present == 7)
        #expect(crumbs.reported.isEmpty)
    }
}
