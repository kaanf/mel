import Foundation
import MelSpec
import Synchronization

/// Runs one agent process at a time. The process gets its own process group so stop signals
/// reach anything it spawned; all pipe I/O happens on background threads.
public actor AgentRunner: AgentRunning {
    let adapter: any AgentAdapter
    let executable: URL
    let timeout: Duration
    private var path: String?
    private var current: RunState?

    public init(adapter: any AgentAdapter, executable: URL, timeout: Duration = .seconds(120)) {
        self.adapter = adapter
        self.executable = executable
        self.timeout = timeout
    }

    public nonisolated func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.start(request, continuation) }
            continuation.onTermination = { termination in
                if case .cancelled = termination { Task { await self.stop() } }
            }
        }
    }

    /// SIGINT to the process group, SIGTERM after 3 s. The stream ends with `failed(.user)`.
    public func stop() async {
        current?.stop(.user)
    }

    private func start(_ request: AgentRequest, _ continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation) async {
        if path == nil {
            path = ([executable.deletingLastPathComponent().path, await ShellPath.loginPATH()])
                .filter { !$0.isEmpty }.joined(separator: ":")
        }
        let process: Spawned
        do {
            process = try Spawned(executable: executable, arguments: adapter.arguments(for: request),
                                  environment: adapter.environment(path: path ?? ""),
                                  directory: request.workingDirectory)
        } catch {
            continuation.finish(throwing: error)
            return
        }
        let state = RunState(pid: process.pid)
        current = state

        let prompt = Data(request.prompt.utf8)
        DispatchQueue.global().async { process.writeInput(prompt) }

        let stderrDone = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.readLines(process.stderr, splitLines: false) { state.appendStderr($0) }
            stderrDone.signal()
        }

        let watchdog = Task.detached { [timeout] in
            while !Task.isCancelled {
                let deadline = state.lastOutput + timeout
                if ContinuousClock.now >= deadline { state.stop(.timeout); return }
                try? await Task.sleep(until: deadline, clock: .continuous)
            }
        }

        let adapter = adapter
        DispatchQueue.global().async {
            var terminal: AgentEvent?
            var limited = false
            var resetsAt: Date?

            process.readLines(process.stdout, splitLines: true) { line in
                state.touch()
                for event in adapter.parse(line: Substring(String(decoding: line, as: UTF8.self))) where terminal == nil {
                    switch event {
                    case .rateLimit(let allowed, let resets):
                        limited = limited || !allowed
                        resetsAt = resets ?? resetsAt
                        continuation.yield(event)
                    case .failed(let reason):
                        terminal = .failed(state.stopReason ?? Self.refine(reason, limited: limited, resetsAt: resetsAt))
                        state.terminate()
                    case .done:
                        terminal = event
                    default:
                        continuation.yield(event)
                    }
                }
            }

            let status = process.waitForExit()
            state.markExited()
            watchdog.cancel()
            _ = stderrDone.wait(timeout: .now() + 1)

            let final = terminal ?? .failed(state.stopReason ?? .crashed(state.stderrTail.isEmpty
                ? "Claude Code exited with status \(status) without a result."
                : state.stderrTail))
            continuation.yield(final)
            continuation.finish()
        }
    }

    /// A failure after a rejected rate limit is a usage limit; a usage limit gets the last known reset time.
    static func refine(_ reason: StopReason, limited: Bool, resetsAt: Date?) -> StopReason {
        switch reason {
        case .usageLimit(nil): .usageLimit(resetsAt: resetsAt)
        case .crashed where limited: .usageLimit(resetsAt: resetsAt)
        default: reason
        }
    }
}

/// Shared between the actor, the pipe threads and the watchdog.
final class RunState: Sendable {
    static let stderrLimit = 64 * 1024

    private struct Values {
        var lastOutput = ContinuousClock.now
        var stopReason: StopReason?
        var exited = false
        var stderr: [UInt8] = []
    }

    let pid: pid_t
    private let values = Mutex(Values())

    init(pid: pid_t) { self.pid = pid }

    var lastOutput: ContinuousClock.Instant { values.withLock { $0.lastOutput } }
    var stopReason: StopReason? { values.withLock { $0.stopReason } }
    var stderrTail: String { values.withLock { String(decoding: $0.stderr, as: UTF8.self) } }

    func touch() { values.withLock { $0.lastOutput = .now } }
    func markExited() { values.withLock { $0.exited = true } }

    func appendStderr(_ bytes: ArraySlice<UInt8>) {
        values.withLock {
            $0.stderr.append(contentsOf: bytes)
            if $0.stderr.count > Self.stderrLimit { $0.stderr.removeFirst($0.stderr.count - Self.stderrLimit) }
        }
    }

    /// First reason wins. SIGINT now, SIGTERM after 3 s if still running.
    func stop(_ reason: StopReason) {
        let first = values.withLock { v in
            guard v.stopReason == nil, !v.exited else { return false }
            v.stopReason = reason
            return true
        }
        guard first else { return }
        send(SIGINT)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { self.send(SIGTERM) }
    }

    /// Ends a run the stream already failed (e.g. API key in use).
    func terminate() { send(SIGTERM) }

    private func send(_ sig: Int32) {
        guard !values.withLock({ $0.exited }) else { return }
        kill(-pid, sig)
    }
}

struct SpawnError: LocalizedError {
    var code: Int32
    var errorDescription: String? { "Couldn't start Claude Code: \(String(cString: strerror(code)))" }
}

/// A child process in its own process group with piped stdin, stdout and stderr.
struct Spawned: Sendable {
    let pid: pid_t
    let stdin: Int32
    let stdout: Int32
    let stderr: Int32

    init(executable: URL, arguments: [String], environment: [String: String], directory: URL) throws {
        var input: [Int32] = [0, 0], output: [Int32] = [0, 0], errors: [Int32] = [0, 0]
        guard pipe(&input) == 0, pipe(&output) == 0, pipe(&errors) == 0 else { throw SpawnError(code: errno) }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, input[0], 0)
        posix_spawn_file_actions_adddup2(&actions, output[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errors[1], 2)
        posix_spawn_file_actions_addchdir(&actions, directory.path)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // Own process group; only the dup2'd descriptors are inherited; default signal handling.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
                                                    | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
        posix_spawnattr_setpgroup(&attributes, 0)
        var all = sigset_t(), none = sigset_t()
        sigfillset(&all)
        sigemptyset(&none)
        posix_spawnattr_setsigdefault(&attributes, &all)
        posix_spawnattr_setsigmask(&attributes, &none)

        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }

        var pid: pid_t = 0
        let result = posix_spawn(&pid, executable.path, &actions, &attributes, argv, envp)
        close(input[0]); close(output[1]); close(errors[1])
        guard result == 0 else {
            close(input[1]); close(output[0]); close(errors[0])
            throw SpawnError(code: result)
        }
        _ = fcntl(input[1], F_SETNOSIGPIPE, 1)  // a child that exits early must not kill the app
        self.pid = pid
        stdin = input[1]
        stdout = output[0]
        stderr = errors[0]
    }

    func writeInput(_ data: Data) {
        data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let n = write(stdin, buffer.baseAddress! + offset, buffer.count - offset)
                if n < 0 { if errno == EINTR { continue } else { break } }
                offset += n
            }
        }
        close(stdin)
    }

    /// Blocking read until EOF, then closes `fd`. With `splitLines`, calls `body` once per line
    /// (without the newline); otherwise once per chunk.
    func readLines(_ fd: Int32, splitLines: Bool, _ body: (ArraySlice<UInt8>) -> Void) {
        var pending: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = read(fd, &buffer, buffer.count)
            if n < 0, errno == EINTR { continue }
            guard n > 0 else { break }
            guard splitLines else { body(buffer[..<n]); continue }
            pending.append(contentsOf: buffer[..<n])
            var start = 0
            while let newline = pending[start...].firstIndex(of: 0x0A) {
                if newline > start { body(pending[start..<newline]) }
                start = newline + 1
            }
            pending.removeFirst(start)
        }
        if splitLines, !pending.isEmpty { body(pending[...]) }
        close(fd)
    }

    /// Exit code, or 128 + signal number when killed.
    func waitForExit() -> Int32 {
        var status: Int32 = 0
        while waitpid(pid, &status, 0) < 0, errno == EINTR {}
        return status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + status & 0x7f
    }
}
