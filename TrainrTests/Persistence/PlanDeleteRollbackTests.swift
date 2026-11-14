import Foundation
import SwiftData
import Testing
@testable import Trainr

// Nothing here reproduces a tap either: the delete only fails on a store the
// app can no longer write to. It pins that a week is not taken away by a save
// that never landed.
@Suite("A plan delete whose save fails")
struct PlanDeleteRollbackTests {

    private static func seededStore() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "trainr.store")
        let store = TrainingStore(container: try TrainingStore.container(url: url))
        let profile = UserProfile(firstName: "Jericho", age: 30)
        try store.saveUser(profile)
        var plan = SampleWorkoutData.weekOne
        plan.userID = profile.id
        try store.savePlan(plan)
        return url
    }

    private static func permissions(_ url: URL, _ mode: Int) throws {
        let manager = FileManager.default
        for suffix in ["", "-wal", "-shm"] where manager.fileExists(atPath: url.path + suffix) {
            try manager.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path + suffix)
        }
    }

    @Test("A save that would not take leaves no delete behind to be committed later")
    func aFailedDeleteIsTakenBack() throws {
        let url = try Self.seededStore()
        try Self.permissions(url, 0o444)
        defer { try? Self.permissions(url, 0o644) }

        let store = TrainingStore(container: try TrainingStore.container(url: url))
        let profile = try #require(try store.currentUser())
        let plan = try #require(try store.plan(for: profile.id, weekNumber: 1))

        #expect(throws: (any Error).self) { try store.deletePlan(id: plan.id) }
        #expect(!store.container.mainContext.hasChanges)
    }

    // The known limit, pinned rather than claimed. On iOS 26 the row survives but
    // this context has let the week go, so it takes a relaunch to read; iOS 27
    // hands it straight back, the same split as delete-then-relink.
    @Test("Though before iOS 27 it takes a relaunch before that week reads again")
    func theRolledBackWeekNeedsARelaunchBeforeIOS27() throws {
        let url = try Self.seededStore()
        try Self.permissions(url, 0o444)
        defer { try? Self.permissions(url, 0o644) }

        let store = TrainingStore(container: try TrainingStore.container(url: url))
        let profile = try #require(try store.currentUser())
        let plan = try #require(try store.plan(for: profile.id, weekNumber: 1))

        #expect(throws: (any Error).self) { try store.deletePlan(id: plan.id) }

        if #available(iOS 27, *) {
            #expect(try store.plan(for: profile.id, weekNumber: plan.weekNumber) != nil)
        } else {
            #expect(try store.plan(for: profile.id, weekNumber: plan.weekNumber) == nil)
        }
    }

    // The same pending delete, on the profile every week hangs off: a save that
    // never landed must not leave the cascade waiting for an unrelated one.
    @Test("A profile save that would not take leaves no delete behind either")
    func aFailedProfileSaveIsTakenBack() throws {
        let url = try Self.seededStore()
        try Self.permissions(url, 0o444)
        defer { try? Self.permissions(url, 0o644) }

        let store = TrainingStore(container: try TrainingStore.container(url: url))
        let profile = try #require(try store.currentUser())

        #expect(throws: (any Error).self) { try store.saveUser(profile) }
        #expect(!store.container.mainContext.hasChanges)
    }

    @Test("And the week itself is still on the disk it was never taken off")
    func theWeekIsStillOnTheDisk() throws {
        let url = try Self.seededStore()
        try Self.permissions(url, 0o444)

        let store = TrainingStore(container: try TrainingStore.container(url: url))
        let profile = try #require(try store.currentUser())
        let plan = try #require(try store.plan(for: profile.id, weekNumber: 1))
        #expect(throws: (any Error).self) { try store.deletePlan(id: plan.id) }

        try Self.permissions(url, 0o644)
        let reopened = TrainingStore(container: try TrainingStore.container(url: url))
        #expect(try reopened.plan(for: profile.id, weekNumber: plan.weekNumber) != nil)
    }
}
