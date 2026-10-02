import CryptoKit
import Foundation
import Observation
import os

@Observable
final class ModelInstaller: LocalModelInstaller {

    private(set) var state: ModelState

    nonisolated let file: URL
    nonisolated var readyFile: URL? { readiness.withLock { $0 } ? file : nil }

    private let artifact: ModelArtifact
    private let directory: URL
    private let candidate: URL
    private let resumeFile: URL
    private let eligibility: DeviceEligibility
    private let freeSpace: @Sendable (URL) -> Int64
    private let session: URLSession
    private let transfer: Transfer
    private let readiness = OSAllocatedUnfairLock(initialState: false)
    private var download: URLSessionDownloadTask?
    private var verification: Task<Void, Never>?

    private nonisolated static let bufferBytes = 256 * 1024

    init(
        directory: URL,
        eligibility: DeviceEligibility,
        artifact: ModelArtifact = .lfm25,
        configuration: URLSessionConfiguration,
        freeSpace: @escaping @Sendable (URL) -> Int64
    ) {
        self.artifact = artifact
        self.directory = directory
        self.eligibility = eligibility
        self.freeSpace = freeSpace
        file = directory.appending(path: artifact.fileName)
        candidate = directory.appending(path: artifact.fileName + ".part")
        resumeFile = directory.appending(path: artifact.fileName + ".resume")
        transfer = Transfer(candidate: candidate)
        session = URLSession(configuration: configuration, delegate: transfer, delegateQueue: nil)
        let initial = Self.stateOnDisk(file, candidate: candidate, artifact: artifact, eligibility: eligibility)
        state = initial
        readiness.withLock { $0 = initial == .ready }
        transfer.installer = self
        if state == .verifying { verify(Self.size(of: file) == nil ? candidate : file) }
        session.getTasksWithCompletionHandler { [weak self] _, _, downloads in
            Task { @MainActor in self?.adopt(downloads.first) }
        }
    }

    func install() {
        switch state {
        case .notInstalled, .insufficientStorage, .failed: break
        case .unsupported, .downloading, .verifying, .ready: return
        }
        guard freeSpace(directory) >= 2 * artifact.sizeBytes else {
            transition(to: .insufficientStorage)
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            Self.excludeFromBackup(directory)
        } catch {
            transition(to: .failed(.download))
            return
        }
        let task = Self.resumeData(at: resumeFile).map { session.downloadTask(withResumeData: $0) }
            ?? session.downloadTask(with: artifact.url)
        download = task
        transition(to: .downloading(done: 0, total: artifact.sizeBytes))
        task.resume()
    }

    func cancel() {
        download?.cancel { [resumeFile] data in try? data?.write(to: resumeFile, options: .atomic) }
        verification?.cancel()
    }

    fileprivate func progressed(_ done: Int64) {
        guard case .downloading = state else { return }
        transition(to: .downloading(done: min(done, artifact.sizeBytes), total: artifact.sizeBytes))
    }

    fileprivate func finished(downloaded: Bool) {
        download = nil
        try? FileManager.default.removeItem(at: resumeFile)
        if downloaded {
            verify(candidate)
        } else {
            transition(to: .failed(.download))
        }
    }

    fileprivate func ended(cancelled: Bool, resumeData: Data?) {
        download = nil
        if let resumeData {
            try? resumeData.write(to: resumeFile, options: .atomic)
        } else if !cancelled {
            try? FileManager.default.removeItem(at: resumeFile)
        }
        transition(to: cancelled ? .notInstalled : .failed(.download))
    }

    private func adopt(_ task: URLSessionDownloadTask?) {
        guard let task, download == nil, state == .notInstalled else { return }
        download = task
        transition(to: .downloading(done: task.countOfBytesReceived, total: artifact.sizeBytes))
    }

    private func verify(_ candidate: URL) {
        transition(to: .verifying)
        verification = Task.detached(priority: .utility) { [weak self] in
            let hash = Self.sha256(of: candidate)
            await self?.verified(candidate, hash: hash)
        }
    }

    private func verified(_ candidate: URL, hash: String?) {
        verification = nil
        if Task.isCancelled {
            transition(to: .notInstalled)
            return
        }
        if hash == artifact.sha256, candidate == file || Self.rename(candidate, to: file) {
            Self.excludeFromBackup(file)
            transition(to: .ready)
        } else {
            try? FileManager.default.removeItem(at: candidate)
            transition(to: .failed(.hashMismatch))
        }
    }

    private func transition(to next: ModelState) {
        state = next
        readiness.withLock { $0 = next == .ready }
    }

    private nonisolated static func stateOnDisk(
        _ file: URL, candidate: URL, artifact: ModelArtifact, eligibility: DeviceEligibility
    ) -> ModelState {
        guard eligibility.isSupported else { return .unsupported }
        if let size = size(of: file) { return size == artifact.sizeBytes ? .ready : .verifying }
        return size(of: candidate) == nil ? .notInstalled : .verifying
    }

    // Anything but a property list dictionary makes URLSession throw.
    private nonisolated static func resumeData(at file: URL) -> Data? {
        guard let data = try? Data(contentsOf: file),
              (try? PropertyListSerialization.propertyList(from: data, format: nil)) is [String: Any]
        else { return nil }
        return data
    }

    private nonisolated static func size(of file: URL) -> Int64? {
        try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64
    }

    private nonisolated static func sha256(of file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while !Task.isCancelled {
            let chunk: Data?
            do { chunk = try handle.read(upToCount: bufferBytes) } catch { return nil }
            guard let chunk, !chunk.isEmpty else {
                return hasher.finalize().map { String(format: "%02x", $0) }.joined()
            }
            hasher.update(data: chunk)
        }
        return nil
    }

    private nonisolated static func rename(_ candidate: URL, to file: URL) -> Bool {
        try? FileManager.default.removeItem(at: file)
        return (try? FileManager.default.moveItem(at: candidate, to: file)) != nil
    }

    private nonisolated static func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}

private nonisolated final class Transfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    weak var installer: ModelInstaller?
    private let candidate: URL

    init(candidate: URL) {
        self.candidate = candidate
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        notify { $0.progressed(totalBytesWritten) }
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64
    ) {
        notify { $0.progressed(fileOffset) }
    }

    // The file at `location` is gone once this returns, so it is moved here
    // and not on the main actor.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        try? FileManager.default.removeItem(at: candidate)
        let moved = (try? FileManager.default.moveItem(at: location, to: candidate)) != nil
        notify { $0.finished(downloaded: moved) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else { return }
        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let cancelled = (error as? URLError)?.code == .cancelled
        notify { $0.ended(cancelled: cancelled, resumeData: resumeData) }
    }

    private func notify(_ action: @escaping @MainActor (ModelInstaller) -> Void) {
        Task { @MainActor [weak installer] in
            if let installer { action(installer) }
        }
    }
}
