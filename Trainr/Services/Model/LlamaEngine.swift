import Foundation
import TrainrDependencies
import UIKit
import os

nonisolated enum CompletionResult: Equatable, Sendable {
    case text(String)
    case timeout
    case cancelled
    case failed
    case outOfMemory
}

nonisolated protocol LocalModel: Sendable {
    func complete(
        system: String, user: String, grammar: String, maxTokens: Int, timeout: Duration
    ) async -> CompletionResult
}

actor LlamaEngine: LocalModel {

    private let modelFile: @Sendable () -> URL?
    private let availableMemory: @Sendable () -> UInt64
    private let queue = DispatchQueue(label: "com.jericx.trainr.llama", qos: .userInitiated)
    private var session: LlamaSession?
    private var releaseRequested = false
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(
        modelFile: @escaping @Sendable () -> URL?,
        availableMemory: @escaping @Sendable () -> UInt64 = { UInt64(os_proc_available_memory()) }
    ) {
        self.modelFile = modelFile
        self.availableMemory = availableMemory
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { await self?.memoryWarning() }
        }
    }

    func complete(
        system: String, user: String, grammar: String, maxTokens: Int, timeout: Duration
    ) async -> CompletionResult {
        await waitForTurn()
        defer { endTurn() }
        guard let file = modelFile() else { return .failed }
        releaseRequested = false
        guard let session = await loadIfNeeded(file) else {
            return availableMemory() < Self.size(of: file) ? .outOfMemory : .failed
        }
        let result = await run(
            session, system: system, user: user, grammar: grammar, maxTokens: maxTokens, timeout: timeout
        )
        if releaseRequested { self.session = nil }
        return result
    }

    private func loadIfNeeded(_ file: URL) async -> LlamaSession? {
        if let session { return session }
        let threads = Self.threads
        let loaded = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: LlamaSession.load(file, threads: threads)) }
        }
        session = loaded
        return loaded
    }

    private func run(
        _ session: LlamaSession, system: String, user: String, grammar: String, maxTokens: Int, timeout: Duration
    ) async -> CompletionResult {
        session.interrupt.reset()
        let timer = Task {
            guard (try? await Task.sleep(for: timeout)) != nil else { return }
            session.interrupt.raise(.timeout)
        }
        defer { timer.cancel() }
        let text = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(
                        returning: session.complete(system: system, user: user, grammar: grammar, maxTokens: maxTokens)
                    )
                }
            }
        } onCancel: {
            session.interrupt.raise(.cancelled)
        }
        if let text { return .text(text) }
        switch session.interrupt.reason {
        case .timeout: return .timeout
        case .cancelled, .memory: return .cancelled
        case .none: return .failed
        }
    }

    private func memoryWarning() {
        releaseRequested = true
        session?.interrupt.raise(.memory)
        if !busy { session = nil }
    }

    private func waitForTurn() async {
        if !busy {
            busy = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func endTurn() {
        if waiting.isEmpty {
            busy = false
        } else {
            waiting.removeFirst().resume()
        }
    }

    private static var threads: Int32 {
        Int32(max(2, min(6, ProcessInfo.processInfo.activeProcessorCount - 1)))
    }

    private static func size(of file: URL) -> UInt64 {
        (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? UInt64) ?? 0
    }
}

nonisolated final class Interrupt: Sendable {

    enum Reason: Sendable {
        case none, timeout, cancelled, memory
    }

    private let state = OSAllocatedUnfairLock(initialState: Reason.none)

    var reason: Reason { state.withLock { $0 } }

    var isRaised: Bool { reason != .none }

    func raise(_ reason: Reason) {
        state.withLock { if $0 == .none { $0 = reason } }
    }

    func reset() {
        state.withLock { $0 = .none }
    }
}

private nonisolated func shouldAbort(_ data: UnsafeMutableRawPointer?) -> Bool {
    guard let data else { return false }
    return Unmanaged<Interrupt>.fromOpaque(data).takeUnretainedValue().isRaised
}

private nonisolated func forwardLog(
    _ level: ggml_log_level, _ text: UnsafePointer<CChar>?, _ data: UnsafeMutableRawPointer?
) {
    if level == GGML_LOG_LEVEL_ERROR, let text { fputs(text, stderr) }
}

nonisolated final class LlamaSession: @unchecked Sendable {

    let interrupt: Interrupt
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer

    private static let contextTokens: UInt32 = 2048
    private static let batchTokens: UInt32 = 512
    private static let backend: Void = {
        llama_log_set(forwardLog, nil)
        llama_backend_init()
    }()

    private init(interrupt: Interrupt, model: OpaquePointer, context: OpaquePointer, vocab: OpaquePointer) {
        self.interrupt = interrupt
        self.model = model
        self.context = context
        self.vocab = vocab
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    static func load(_ file: URL, threads: Int32) -> LlamaSession? {
        _ = backend
        var modelParams = llama_model_default_params()
        modelParams.load_mode = LLAMA_LOAD_MODE_MMAP
        // Repacked weights run five times slower than mapped ones on this build.
        modelParams.use_extra_bufts = false
        // Cancellation only reaches CPU work, so nothing is offloaded.
        modelParams.n_gpu_layers = 0
        guard let model = file.withUnsafeFileSystemRepresentation({ path in
            path.flatMap { llama_model_load_from_file($0, modelParams) }
        }) else { return nil }

        let interrupt = Interrupt()
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = contextTokens
        contextParams.n_batch = batchTokens
        contextParams.n_ubatch = batchTokens
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads
        contextParams.op_offload = false
        contextParams.abort_callback = shouldAbort
        contextParams.abort_callback_data = Unmanaged.passUnretained(interrupt).toOpaque()
        guard let context = llama_init_from_model(model, contextParams),
              let vocab = llama_model_get_vocab(model)
        else {
            llama_model_free(model)
            return nil
        }
        return LlamaSession(interrupt: interrupt, model: model, context: context, vocab: vocab)
    }

    func complete(system: String, user: String, grammar: String, maxTokens: Int) -> String? {
        guard let prompt = formatPrompt(system: system, user: user),
              var tokens = tokenize(prompt),
              tokens.count + maxTokens <= Int(llama_n_ctx(context)),
              let grammarSampler = grammar.withCString({ llama_sampler_init_grammar(vocab, $0, "root") }),
              let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
        else { return nil }
        llama_sampler_chain_add(sampler, grammarSampler)
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy())
        defer { llama_sampler_free(sampler) }

        llama_memory_clear(llama_get_memory(context), true)
        guard decode(&tokens) else { return nil }

        var bytes: [UInt8] = []
        for _ in 0..<maxTokens {
            if interrupt.isRaised { return nil }
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            guard appendPiece(token, to: &bytes), llama_decode(context, llama_batch_get_one(&token, 1)) == 0
            else { return nil }
        }
        return String(bytes: bytes, encoding: .utf8)
    }

    private func formatPrompt(system: String, user: String) -> String? {
        guard let template = llama_model_chat_template(model, nil) else { return nil }
        return Self.withCStrings(["system", system, "user", user]) { texts in
            let messages = [
                llama_chat_message(role: texts[0], content: texts[1]),
                llama_chat_message(role: texts[2], content: texts[3])
            ]
            var buffer = [CChar](repeating: 0, count: (system.utf8.count + user.utf8.count) * 2 + 256)
            var written = Self.apply(template, messages, into: &buffer)
            if written > buffer.count {
                buffer = [CChar](repeating: 0, count: Int(written))
                written = Self.apply(template, messages, into: &buffer)
            }
            guard written >= 0 else { return nil }
            return String(bytes: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, encoding: .utf8)
        }
    }

    private static func apply(
        _ template: UnsafePointer<CChar>, _ messages: [llama_chat_message], into buffer: inout [CChar]
    ) -> Int32 {
        messages.withUnsafeBufferPointer { chat in
            buffer.withUnsafeMutableBufferPointer { out in
                llama_chat_apply_template(
                    template, chat.baseAddress, chat.count, true, out.baseAddress, Int32(out.count)
                )
            }
        }
    }

    private static func withCStrings<R>(
        _ strings: ArraySlice<String>, _ collected: [UnsafePointer<CChar>] = [], _ body: ([UnsafePointer<CChar>]) -> R
    ) -> R {
        guard let first = strings.first else { return body(collected) }
        return first.withCString { withCStrings(strings.dropFirst(), collected + [$0], body) }
    }

    private static func withCStrings<R>(_ strings: [String], _ body: ([UnsafePointer<CChar>]) -> R) -> R {
        withCStrings(strings[...], [], body)
    }

    private func tokenize(_ text: String) -> [llama_token]? {
        let utf8 = Array(text.utf8)
        return utf8.withUnsafeBufferPointer { buffer -> [llama_token]? in
            guard let base = buffer.baseAddress else { return nil }
            let chars = UnsafeRawPointer(base).assumingMemoryBound(to: CChar.self)
            let length = Int32(buffer.count)
            let needed = llama_tokenize(vocab, chars, length, nil, 0, true, true)
            guard needed != Int32.min else { return nil }
            var tokens = [llama_token](repeating: 0, count: Int(needed.magnitude))
            let written = tokens.withUnsafeMutableBufferPointer { out in
                llama_tokenize(vocab, chars, length, out.baseAddress, Int32(out.count), true, true)
            }
            guard written >= 0 else { return nil }
            return Array(tokens.prefix(Int(written)))
        }
    }

    private func decode(_ tokens: inout [llama_token]) -> Bool {
        let batch = Int(Self.batchTokens)
        return tokens.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return true }
            for offset in stride(from: 0, to: buffer.count, by: batch) {
                let count = Int32(min(batch, buffer.count - offset))
                if llama_decode(context, llama_batch_get_one(base + offset, count)) != 0 { return false }
            }
            return true
        }
    }

    private func appendPiece(_ token: llama_token, to bytes: inout [UInt8]) -> Bool {
        var piece = [CChar](repeating: 0, count: 64)
        var length = piece.withUnsafeMutableBufferPointer {
            llama_token_to_piece(vocab, token, $0.baseAddress, Int32($0.count), 0, false)
        }
        if length < 0 {
            piece = [CChar](repeating: 0, count: Int(-length))
            length = piece.withUnsafeMutableBufferPointer {
                llama_token_to_piece(vocab, token, $0.baseAddress, Int32($0.count), 0, false)
            }
        }
        guard length >= 0 else { return false }
        bytes.append(contentsOf: piece.prefix(Int(length)).map { UInt8(bitPattern: $0) })
        return true
    }
}
