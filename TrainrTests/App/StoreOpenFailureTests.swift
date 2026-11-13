import Foundation
import SwiftData
import Testing
@testable import Trainr

// Nothing here reproduces a tap: no screen can reach a store that will not
// open. It pins that a failed open is refused rather than quietly replaced by
// one that dies with the process.
@Suite("A store that will not open")
struct StoreOpenFailureTests {

    private final class Crumbs: Breadcrumbs {
        var events: [String] = []
        var reported: [String] = []
        func record(_ event: String) { events.append(event) }
        func report(_ error: any Error, doing action: String) { reported.append(action) }
    }

    private static func unreadableStore() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "trainr.store")
        try Data("this is not a database".utf8).write(to: url)
        return url
    }

    @Test("A store file that cannot be read is not a store the app opens at all")
    func anUnreadableStoreThrowsRatherThanOpeningEmpty() throws {
        let url = try Self.unreadableStore()
        #expect(throws: (any Error).self) { try TrainingStore.container(url: url) }
    }

    @Test("A failed open hands back nothing, and never an in-memory stand-in")
    func aFailedOpenHandsBackNothing() throws {
        let url = try Self.unreadableStore()
        let crumbs = Crumbs()
        let dependencies = AppDependencies.live(breadcrumbs: crumbs) { _ in
            try TrainingStore.container(url: url)
        }
        #expect(dependencies == nil)
        #expect(crumbs.reported == ["openTrainingStore"])
    }
}
