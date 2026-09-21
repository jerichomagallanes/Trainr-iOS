import Foundation
import Testing
@testable import Trainr

// A copy of the handoff's own behavior-cases.json, read from the source tree
// so it stays diffable against it. Both apps are held to this list, so a route
// added to it has to land somewhere on this side too rather than be ignored.
@Suite("The shared behaviour cases")
struct BehaviorCaseFixtureTests {

    private static let file = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/behavior-cases.json")

    private let routes: [(id: String, route: String)]

    init() throws {
        let data = try Data(contentsOf: Self.file)
        let read = try JSONSerialization.jsonObject(with: data)
        let cases = try #require((read as? [String: Any])?["cases"] as? [[String: Any]])
        routes = try cases.map {
            (try #require($0["id"] as? String), try #require($0["expectedIntentOrRoute"] as? String))
        }
    }

    // The two the policy answers are its own reasons; the rest are routes this
    // app deliberately does not automate — pain above all (C11).
    private static let unautomated: Set<String> = [
        "exercise_guidance", "pain_concern", "other_or_unclear"
    ]

    private static var automated: Set<String> {
        Set(AdjustmentReason.allCases.map { $0.rawValue.lowercased() })
    }

    @Test("Every case names a route this app knows")
    func everyCaseNamesAKnownRoute() {
        #expect(!routes.isEmpty)

        for (id, route) in routes {
            #expect(
                Self.automated.contains(route) || Self.unautomated.contains(route),
                "case \(id) expects \(route)"
            )
        }
    }

    @Test("Both of the reasons the policy answers are exercised by the cases")
    func theCasesCoverEveryAutomatedRoute() {
        #expect(Set(routes.map(\.route)).isSuperset(of: Self.automated))
    }

    @Test("A route is either automated or deliberately not, never both")
    func theTwoListsDoNotOverlap() {
        #expect(Self.automated.isDisjoint(with: Self.unautomated))
    }
}
