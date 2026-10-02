import CryptoKit
import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Installing the local model", .serialized)
struct ModelInstallerTests {

    fileprivate nonisolated static let size: Int64 = 3_000_000

    private let directory: URL
    private let supported = DeviceEligibility(physicalMemory: 4 << 30, isArm64: true)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "installer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        StubModelProtocol.reset()
    }

    private var file: URL { directory.appending(path: "lfm25-q4km.gguf") }
    private var resumeFile: URL { directory.appending(path: "lfm25-q4km.gguf.resume") }

    private func artifact(sha256: String? = nil) -> ModelArtifact {
        var artifact = ModelArtifact.lfm25
        artifact.url = StubModelProtocol.url
        artifact.sizeBytes = Self.size
        artifact.sha256 = sha256 ?? StubModelProtocol.patternHash(size: Self.size)
        return artifact
    }

    private func installer(
        artifact: ModelArtifact? = nil,
        eligibility: DeviceEligibility? = nil,
        freeBytes: Int64 = 4 * ModelInstallerTests.size
    ) -> ModelInstaller {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubModelProtocol.self]
        return ModelInstaller(
            directory: directory,
            eligibility: eligibility ?? supported,
            artifact: artifact ?? self.artifact(),
            configuration: configuration,
            freeSpace: { _ in freeBytes }
        )
    }

    @discardableResult
    private func settle(
        _ installer: ModelInstaller, seconds: Double = 15, until done: (ModelState) -> Bool
    ) async throws -> [ModelState] {
        var seen: [ModelState] = [installer.state]
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !done(installer.state) {
            try #require(ContinuousClock.now < deadline, "timed out in \(installer.state)")
            try await Task.sleep(for: .milliseconds(20))
            if installer.state != seen.last { seen.append(installer.state) }
        }
        return seen
    }

    private func write(_ length: Int64, to url: URL) throws {
        try Data().write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(length))
        try handle.close()
    }

    private func contents() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    @Test("An unsupported device never offers the model")
    func anUnsupportedDeviceNeverOffersTheModel() async {
        let installer = installer(eligibility: DeviceEligibility(physicalMemory: 2 << 30, isArm64: true))

        installer.install()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(installer.state == .unsupported)
        #expect(StubModelProtocol.requests.isEmpty)
    }

    @Test("Too little free space is refused before any byte is fetched")
    func tooLittleFreeSpaceIsRefusedBeforeAnyByteIsFetched() async {
        let installer = installer(freeBytes: Self.size + 1)

        installer.install()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(installer.state == .insufficientStorage)
        #expect(StubModelProtocol.requests.isEmpty)
    }

    @Test("A second tap while downloading opens no second connection")
    func aSecondTapWhileDownloadingOpensNoSecondConnection() async throws {
        StubModelProtocol.pauseAt = 1_000_000
        let installer = installer()

        installer.install()
        installer.install()
        try await settle(installer) { if case let .downloading(done, _) = $0 { done >= 1_000_000 } else { false } }

        #expect(StubModelProtocol.requests.count == 1)
    }

    @Test("A good download is checked, renamed and kept out of backup")
    func aGoodDownloadIsCheckedRenamedAndKeptOutOfBackup() async throws {
        let installer = installer()

        installer.install()
        try await settle(installer) { $0 == .ready }

        #expect(installer.readyFile == file)
        #expect(try contents() == ["lfm25-q4km.gguf"])
        let values = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("A hash mismatch deletes the file and reports it")
    func aHashMismatchDeletesTheFileAndReportsIt() async throws {
        let installer = installer(artifact: artifact(sha256: String(repeating: "0", count: 64)))

        installer.install()
        let seen = try await settle(installer) { $0 == .failed(.hashMismatch) }

        #expect(seen.contains { if case .downloading = $0 { true } else { false } })
        #expect(try contents().isEmpty)
        #expect(installer.readyFile == nil)
    }

    @Test("Cancelling keeps the resume data, and the next install picks up from it")
    func cancellingKeepsTheResumeData() async throws {
        StubModelProtocol.pauseAt = 1_000_000
        let installer = installer()
        installer.install()
        try await settle(installer) { if case let .downloading(done, _) = $0 { done >= 1_000_000 } else { false } }

        installer.cancel()
        try await settle(installer) { $0 == .notInstalled }

        #expect(FileManager.default.fileExists(atPath: resumeFile.path))
        #expect(!FileManager.default.fileExists(atPath: file.path))

        StubModelProtocol.pauseAt = nil
        installer.install()
        try await settle(installer) { $0 == .ready }

        #expect(StubModelProtocol.requests.count == 2)
        let range = try #require(StubModelProtocol.requests.last?.value(forHTTPHeaderField: "Range"))
        let resumedFrom = try #require(Int64(range.dropFirst("bytes=".count).prefix { $0 != "-" }))
        #expect(resumedFrom >= 1_000_000 && resumedFrom < Self.size)
        #expect(try contents() == ["lfm25-q4km.gguf"])
    }

    @Test("A server that ignores the range starts over")
    func aServerThatIgnoresTheRangeStartsOver() async throws {
        StubModelProtocol.pauseAt = 1_000_000
        let installer = installer()
        installer.install()
        try await settle(installer) { if case let .downloading(done, _) = $0 { done >= 1_000_000 } else { false } }
        installer.cancel()
        try await settle(installer) { $0 == .notInstalled }

        StubModelProtocol.pauseAt = nil
        StubModelProtocol.honoursRange = false
        installer.install()
        try await settle(installer) { $0 == .ready }

        #expect(StubModelProtocol.requests.count == 2)
        #expect(installer.readyFile == file)
    }

    @Test("A dropped connection reports the download and keeps what can be resumed")
    func aDroppedConnectionReportsTheDownload() async throws {
        StubModelProtocol.failAt = 1_000_000
        let installer = installer()

        installer.install()
        try await settle(installer) { $0 == .failed(.download) }

        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A complete file on disk is ready without a hash")
    func aCompleteFileOnDiskIsReadyWithoutAHash() throws {
        try write(Self.size, to: file)

        let installer = installer()

        #expect(installer.state == .ready)
        #expect(installer.readyFile == file)
    }

    @Test("A file of the wrong length is verified and thrown away")
    func aFileOfTheWrongLengthIsVerifiedAndThrownAway() async throws {
        try Data(count: 10).write(to: file)

        let installer = installer()
        #expect(installer.state == .verifying)
        try await settle(installer) { $0 == .failed(.hashMismatch) }

        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A finished download left unverified is verified on the next start")
    func aFinishedDownloadLeftUnverifiedIsVerifiedOnTheNextStart() async throws {
        let candidate = directory.appending(path: "lfm25-q4km.gguf.part")
        var position: Int64 = 0
        var body = Data()
        while position < Self.size {
            let count = Int(min(64 * 1024, Self.size - position))
            body.append(StubModelProtocol.pattern(from: position, count: count))
            position += Int64(count)
        }
        try body.write(to: candidate)

        let installer = installer()
        #expect(installer.state == .verifying)
        try await settle(installer) { $0 == .ready }

        #expect(StubModelProtocol.requests.isEmpty)
        #expect(try contents() == ["lfm25-q4km.gguf"])
    }

    @Test("A corrupt resume file is ignored and the download starts over")
    func aCorruptResumeFileIsIgnored() async throws {
        try Data("stale".utf8).write(to: resumeFile)
        let installer = installer()

        installer.install()
        try await settle(installer) { $0 == .ready }

        #expect(StubModelProtocol.requests.count == 1)
        #expect(StubModelProtocol.requests.first?.value(forHTTPHeaderField: "Range") == nil)
        #expect(try contents() == ["lfm25-q4km.gguf"])
    }

    @Test("Resume data whose partial file is gone starts the download over")
    func resumeDataWhosePartialFileIsGoneStartsOver() async throws {
        StubModelProtocol.pauseAt = 1_000_000
        let installer = installer()
        installer.install()
        try await settle(installer) { if case let .downloading(done, _) = $0 { done >= 1_000_000 } else { false } }
        installer.cancel()
        try await settle(installer) { $0 == .notInstalled }

        let resume = try PropertyListSerialization.propertyList(from: Data(contentsOf: resumeFile), format: nil)
        let info = try #require(resume as? [String: Any])
        let strings = (info["$objects"] as? [Any])?.compactMap { $0 as? String } ?? []
        let partial = try #require(strings.first { $0.hasSuffix(".tmp") })
        try FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: partial))

        StubModelProtocol.pauseAt = nil
        installer.install()
        try await settle(installer) { $0 == .ready }

        #expect(StubModelProtocol.requests.count == 2)
        #expect(StubModelProtocol.requests.last?.value(forHTTPHeaderField: "Range") == nil)
        #expect(try contents() == ["lfm25-q4km.gguf"])
    }

    @Test("Nothing on disk is not installed")
    func nothingOnDiskIsNotInstalled() {
        #expect(installer().state == .notInstalled)
        #expect(installer().readyFile == nil)
    }
}

// Serves a byte pattern of any length, optionally pausing or dropping partway
// and honouring or ignoring a Range header.
private nonisolated class StubModelProtocol: URLProtocol {

    // swiftlint:disable:next force_unwrapping
    static let url = URL(string: "https://stub.invalid/model/lfm25.gguf")!
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var pauseAt: Int64?
    nonisolated(unsafe) static var failAt: Int64?
    nonisolated(unsafe) static var honoursRange = true
    private static let chunk = 64 * 1024

    static func reset() {
        requests = []
        pauseAt = nil
        failAt = nil
        honoursRange = true
    }

    static func pattern(from position: Int64, count: Int) -> Data {
        Data((0..<count).map { UInt8((position + Int64($0)) % 251) })
    }

    static func patternHash(size: Int64) -> String {
        var hasher = SHA256()
        var position: Int64 = 0
        while position < size {
            let count = Int(min(Int64(chunk), size - position))
            hasher.update(data: pattern(from: position, count: count))
            position += Int64(count)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "stub.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        let total = ModelInstallerTests.size
        var start: Int64 = 0
        var status = 200
        var headers = [
            "Content-Length": "\(total)",
            "ETag": "\"pattern-v1\"",
            "Last-Modified": "Wed, 21 Oct 2015 07:28:00 GMT",
            "Accept-Ranges": "bytes"
        ]
        let range = request.value(forHTTPHeaderField: "Range")?.replacingOccurrences(of: "bytes=", with: "")
        if Self.honoursRange, let from = range.flatMap({ Int64($0.split(separator: "-").first ?? "") }) {
            start = from
            status = 206
            headers["Content-Range"] = "bytes \(from)-\(total - 1)/\(total)"
            headers["Content-Length"] = "\(total - from)"
        }
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
              )
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        var position = start
        while position < total {
            if let pauseAt = Self.pauseAt, position >= pauseAt { return }
            if let failAt = Self.failAt, position >= failAt {
                client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
                return
            }
            let count = Int(min(Int64(Self.chunk), total - position))
            client?.urlProtocol(self, didLoad: Self.pattern(from: position, count: count))
            position += Int64(count)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
