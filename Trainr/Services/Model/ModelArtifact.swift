import Foundation

nonisolated struct ModelArtifact: Equatable, Sendable {
    var url: URL
    var licenceURL: URL
    var fileName: String
    var sizeBytes: Int64
    var sha256: String

    private static let repository = "https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF"

    // swiftlint:disable force_unwrapping
    static let lfm25 = ModelArtifact(
        url: URL(string: repository + "/resolve/main/LFM2.5-1.2B-Instruct-Q4_K_M.gguf")!,
        licenceURL: URL(string: repository + "/blob/main/LICENSE")!,
        fileName: "lfm25-q4km.gguf",
        sizeBytes: 730_895_168,
        sha256: "b1b3de114215d9507409a662a501a631095a479a419584e8a2ded6304b19b4f5"
    )
    // swiftlint:enable force_unwrapping
}
