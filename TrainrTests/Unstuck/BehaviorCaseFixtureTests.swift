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

    private static var automated: Set<String> {
        Set(AdjustmentReason.allCases.map { $0.rawValue.lowercased() })
    }

    // The rest are the intents this app deliberately does not automate — pain
    // above all (C11).
    private static var unautomated: Set<String> {
        Set(IntentKind.allCases.map(\.rawValue)).subtracting(automated)
    }

    @Test("Every case names an intent this app knows")
    func everyCaseNamesAKnownIntent() {
        #expect(!routes.isEmpty)

        for (id, route) in routes {
            #expect(IntentKind(rawValue: route) != nil, "case \(id) expects \(route)")
        }
    }

    @Test("Both of the reasons the policy answers are exercised by the cases")
    func theCasesCoverEveryAutomatedRoute() {
        #expect(Set(routes.map(\.route)).isSuperset(of: Self.automated))
    }

    @Test("Every reason the policy answers is one of the intents")
    func everyAutomatedReasonIsAnIntent() {
        #expect(Set(IntentKind.allCases.map(\.rawValue)).isSuperset(of: Self.automated))
    }

    @Test("Pain is never a reason the policy answers")
    func painIsNeverAutomated() {
        #expect(Self.unautomated.isSuperset(of: [
            IntentKind.exerciseGuidance.rawValue,
            IntentKind.painConcern.rawValue,
            IntentKind.otherOrUnclear.rawValue
        ]))
    }
}
