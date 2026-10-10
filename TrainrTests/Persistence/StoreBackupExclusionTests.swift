import Foundation
import Testing
@testable import Trainr

@Suite("Keeping the store out of backups")
struct StoreBackupExclusionTests {

    private final class RecordingBreadcrumbs: Breadcrumbs {
        var reported: [String] = []
        func record(_ event: String) {}
        func report(_ error: any Error, doing action: String) { reported.append(action) }
    }

    private let folder = URL.temporaryDirectory.appending(path: "backup-exclusion-\(UUID().uuidString)")

    @Test("An on-disk store and every journal file beside it are excluded from backup")
    func anOnDiskStoreIsExcluded() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Trainr.store")
        let crumbs = RecordingBreadcrumbs()

        let container = try TrainingStore.container(url: url, breadcrumbs: crumbs)

        _ = container
        #expect(FileManager.default.fileExists(atPath: url.path))
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            let values = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(values.isExcludedFromBackup == true, "\(file.lastPathComponent)")
        }
        #expect(crumbs.reported.isEmpty)
    }

    @Test("The store file is still where it was")
    func theStoreStaysAtItsURL() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Trainr.store")

        _ = try TrainingStore.container(url: url)

        let written = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(written.contains("Trainr.store"))
        #expect(written.allSatisfy { $0.hasPrefix("Trainr.store") })
    }
}
