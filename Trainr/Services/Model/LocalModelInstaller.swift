import Foundation

nonisolated enum ModelState: Equatable, Sendable {
    case unsupported
    case notInstalled
    case downloading(done: Int64, total: Int64)
    case verifying
    case ready
    case insufficientStorage
    case failed(InstallFailure)
}

nonisolated enum InstallFailure: Equatable, Sendable {
    case download
    case hashMismatch
}

@MainActor
protocol LocalModelInstaller: AnyObject, Sendable {
    var state: ModelState { get }
    // Read off the main actor by the interpreter and the engine, so it answers
    // from its own lock rather than from `state`.
    nonisolated var readyFile: URL? { get }

    func install()

    func cancel()
}

final class UnavailableModelInstaller: LocalModelInstaller {

    let state = ModelState.unsupported
    nonisolated let readyFile: URL? = nil

    func install() {}

    func cancel() {}
}
