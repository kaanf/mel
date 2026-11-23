# Contracts

The types and signatures the three agents share. core stubs **all** of them in Wave 0 (bodies may be `fatalError("stub")` or trivial), so every agent compiles against them from the start. After Wave 0 each file belongs to the agent named in its heading.

Only the orchestrator changes this file. Need a change? Write a request in your status file.

## Project conventions

- Xcode project `Mel.xcodeproj`, scheme `Mel`, app target `Mel`, test target `MelTests` (Swift Testing).
- Both targets use **synchronized folders** (`PBXFileSystemSynchronizedRootGroup`): every file under `Mel/` and `MelTests/` is included automatically. Adding a file never changes `project.pbxproj`.
- macOS 26.0, Swift 6, Xcode's new-app defaults: **default actor isolation `MainActor`**, approachable concurrency. Work that must leave the main actor goes into an `actor` or a `nonisolated`/`@concurrent` function.
- Because the default is `MainActor`, every type below except `AppState`, `SpecSession` and views is declared **`nonisolated`** (and `Sendable` where it crosses actors): the `Spec/` value types, `MarkdownParser`, `AgentTypes`, the `AgentRunning`/`AgentAdapter` protocols, `ClaudeCode`, `ShellPath`, `Git`. New off-main types follow the same rule.
- Don't add `.gitkeep` files. Each existing one needs a pbxproj exception (otherwise "Multiple commands produce .gitkeep"), and a new folder shows up with its first real file anyway.
- Bundle identifier `com.kaanf.mel`. Hardened Runtime on. **No App Sandbox.**
- No third-party dependencies.

```
Mel/
├── App/          ui        MelApp.swift (scenes), commands
├── Views/        ui        one folder per screen, Components/, Preview/ (preview data)
├── Session/      core      AppState, SpecSession
├── Spec/         core      Models, Reducer, MarkdownParser, Prompts/ (*.md resources)
├── Storage/      core      SpecStore, Library, FileWatcher
├── Agent/        platform  AgentTypes, ClaudeCode, AgentRunner, ShellPath
└── System/       platform  SystemActions, Git, Notifier
MelTests/
├── Spec/ Storage/ Session/      core
├── Agent/ System/               platform
└── Fixtures/                    platform   (*.jsonl, fake-claude.sh)
```

## Spec/Models.swift (core)

```swift
import Foundation

struct Spec: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String                  // "Yoga Studio Booking"
    var idea: String
    var folder: URL                   // …/yoga-studio-booking/specs
    var stage: Stage
    var docs: [DocKind: DocStatus]
    var questions: [Question]
    var coverage: [CoverageItem]
    var sessionID: String?
}

enum DocKind: String, Codable, CaseIterable, Hashable {
    case product, requirements, design, tasks
    var fileName: String              // "PRODUCT.md" …
    var title: String                 // "Product" …
}

enum Stage: Codable, Hashable {
    case discovery
    case drafting(DocKind)
    case review(DocKind)
    case stopped(DocKind, StopReason)
    case done
}

enum DocStatus: String, Codable, Hashable { case locked, writing, stopped, review, approved }

struct Question: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var why: String
    var shapes: DocKind
    var options: [Option]             // 2–4; "You decide" is not stored here, the UI adds it
    var answer: Answer?
}

struct Option: Codable, Hashable {
    var label: String
    var note: String
    var suggested: Bool
}

enum Answer: Codable, Hashable {
    case option(Int, note: String?)
    case agentDecides                 // "You decide"
}

struct CoverageItem: Codable, Hashable {
    var label: String
    var state: CoverageState
}

enum CoverageState: String, Codable, Hashable { case covered, asking, notYet }

enum StopReason: Codable, Hashable {
    case user
    case usageLimit(resetsAt: Date?)
    case signedOut
    case crashed(String)              // stderr tail / error text for "Show Details"
    case timeout
}

struct ActivityLine: Hashable, Identifiable {
    let id = UUID()
    var at: Date
    var text: String                  // "read specs/PRODUCT.md"
}
```

## Spec/MarkdownParser.swift (core)

```swift
enum Block: Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case criterion(id: String, text: String)        // "1.1", EARS text
    case task(id: String, text: String, done: Bool, covers: [String])
    case listItem(String)
    case assumption(index: Int, text: String)        // index = order in file, used by confirm/change
    case code(String)
}

struct DocSummary: Hashable {
    var stories: Int
    var criteria: Int
    var sections: Int
    var tasks: Int
    var assumptions: Int
    var uncoveredCriteria: [String]
}

enum MarkdownParser {
    static func blocks(_ text: String) -> [Block]
    static func summary(_ text: String, kind: DocKind) -> DocSummary
}
```

## Agent/AgentTypes.swift (platform)

```swift
import Foundation

enum AgentStatus: Hashable {
    case checking
    case ready(executable: URL, version: String)
    case notSignedIn(executable: URL)
    case missing
    case broken(String)
}

struct AgentRequest: Sendable {
    var prompt: String                // sent on stdin
    var workingDirectory: URL         // project folder (parent of specs/)
    var resumeSessionID: String?
    var persistSession: Bool          // false → --no-session-persistence
}

enum AgentEvent: Sendable, Hashable {
    case session(String)
    case text(String)                 // delta or whole message text
    case step(String)                 // "read specs/PRODUCT.md"
    case rateLimit(allowed: Bool, resetsAt: Date?)
    case done(result: String)         // final result text
    case failed(StopReason)
}

/// What SpecSession depends on. AgentRunner implements it; tests use a fake.
protocol AgentRunning: Sendable {
    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error>
    func stop() async
}

protocol AgentAdapter: Sendable {
    func detect(extraPaths: [String]) async -> AgentStatus
    func loginCommand(executable: URL) -> String
    func arguments(for request: AgentRequest) -> [String]
    func environment(path: String) -> [String: String]
    func parse(line: Substring) -> [AgentEvent]
}
```

`Agent/ClaudeCode.swift`: `struct ClaudeCode: AgentAdapter`. `Agent/AgentRunner.swift`: `actor AgentRunner: AgentRunning { init(adapter: any AgentAdapter, executable: URL, timeout: Duration = .seconds(120)) }`. `Agent/ShellPath.swift`: `enum ShellPath { static func loginPATH() async -> String; static func find(_ name: String, extraPaths: [String]) async -> URL? }`.

## System/ (platform)

```swift
enum SystemActions {
    static func openInTerminal(command: String, in directory: URL) throws   // temp .command file
    static func showInFinder(_ url: URL)
    static func copy(_ text: String)
}

enum Git {
    static var isAvailable: Bool { get }
    static func isRepository(_ url: URL) -> Bool
    static func initRepository(_ url: URL) throws
    static func commit(paths: [String], message: String, in directory: URL) throws
}

enum Notifier {
    static func requestAuthorization() async
    static func post(title: String, body: String, at date: Date? = nil)
}
```

## Session/ (core)

```swift
import Observation

@Observable final class AppState {
    var agent: AgentStatus = .checking
    var extraSearchPaths: [String]
    var specs: [Spec]                         // library, sidebar order
    var selection: Spec.ID?
    var runningSpecID: Spec.ID?               // one agent run at a time across the app

    func scanForAgent() async
    func session(for id: Spec.ID) -> SpecSession
    func createSpec(name: String, idea: String, parentFolder: URL) throws -> SpecSession
    func removeFromLibrary(_ id: Spec.ID)

    static func preview(_ specs: [Spec], agent: AgentStatus) -> AppState
}

@Observable final class SpecSession {
    private(set) var spec: Spec
    private(set) var documents: [DocKind: String]   // current file text
    private(set) var liveText: String               // file text while drafting
    private(set) var activity: [ActivityLine]
    private(set) var isRunning: Bool
    private(set) var lastError: String?             // e.g. unreadable discovery JSON → Retry

    var currentQuestion: Question? { get }
    var answeredQuestions: [Question] { get }
    func summary(_ kind: DocKind) -> DocSummary

    // Discovery
    func start() async
    func answer(_ answer: Answer) async
    func changeAnswer(questionID: String, to answer: Answer) async
    func draftNow() async
    func retry() async

    // Drafting / recovery
    func stop() async
    func resume() async
    func finishByHand()

    // Review
    func save(_ text: String, for kind: DocKind)
    func confirmAssumption(index: Int, in kind: DocKind)
    func changeAssumption(index: Int, to text: String, in kind: DocKind)
    func approve(_ kind: DocKind) async

    static func preview(_ spec: Spec, documents: [DocKind: String] = [:], liveText: String = "", activity: [ActivityLine] = [], isRunning: Bool = false) -> SpecSession
}
```

`preview(…)` factories create inert instances (no disk, no agent) for SwiftUI previews. ui builds its preview data in `Mel/Views/Preview/` on top of them.
