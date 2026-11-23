# Contracts

The types and signatures the three agents share. core stubs **all** of them in Wave 0 (bodies may be `fatalError("stub")` or trivial), so every agent compiles against them from the start. After Wave 0 each file belongs to the agent named in its heading.

Only the orchestrator changes this file. Need a change? Write a request in your status file.

## Project conventions

- Xcode project `Mel.xcodeproj`, shared scheme `Mel`. The app target `Mel` holds only `App/`, `Views/`, `Session/`; its test target `MelTests` holds `Session/` tests.
- Everything below the UI lives in one local Swift package, **`MelKit/`** (`swift-tools-version: 6.2`, `.macOS(.v26)`), referenced by the project. Its library targets are the modules; its test targets are Swift Testing. No third-party dependencies.
- The `Mel` scheme runs **all** tests (app + every MelKit test target), so the one `xcodebuild … test` command in CLAUDE.md stays the only command.
- App targets use synchronized folders (`PBXFileSystemSynchronizedRootGroup`): adding a file never changes `project.pbxproj`. Don't add `.gitkeep` files (each needs a pbxproj exception, otherwise "Multiple commands produce .gitkeep"); a folder shows up with its first real file.
- Bundle identifier `com.kaanf.mel`. Hardened Runtime on. **No App Sandbox.**

### Isolation

- App target: Xcode defaults, **default actor isolation `MainActor`**, approachable concurrency. `AppState`, `SpecSession` and views are main-actor.
- MelKit targets: the package default (**nonisolated**), Swift 6 language mode. Types are plain values, actors or `Sendable`; no `nonisolated` markers needed. Nothing in MelKit is `@MainActor`.

### Layers and dependencies

Dependencies point one way, toward `MelSpec`. The compiler enforces it through the package's target dependencies; the import rule for app folders is checked at merge.

```
MelKit/                        (local package)
├── Sources/
│   ├── MelSpec/      core      domain: Models, Reducer, MarkdownParser, Prompts/ (*.md resources)  → Foundation only
│   ├── MelStorage/   core      SpecStore, Library, FileWatcher                                     → MelSpec
│   ├── MelAgent/     platform  AgentTypes, ClaudeCode, AgentRunner, ShellPath                      → MelSpec
│   └── MelSystem/    platform  SystemActions, Git, Notifier                                        → (none)
└── Tests/
    ├── MelSpecTests/ MelStorageTests/        core
    └── MelAgentTests/ (+ Fixtures/) MelSystemTests/   platform
Mel/                           (app target)
├── App/        ui     MelApp (composition root)  → may import everything
├── Session/    core   AppState, SpecSession       → MelSpec, MelStorage, MelAgent, MelSystem
└── Views/      ui     screens, Components/, Preview/  → SwiftUI, MelSpec, UniformTypeIdentifiers
MelTests/Session/      core
```

Rules:

1. **MelKit modules never import SwiftUI or AppKit**, except `MelSystem`, which may use AppKit for `NSWorkspace`/`NSPasteboard`. `MelSpec` does no I/O beyond reading its own bundled prompt resources.
2. **Modules don't know each other sideways.** `MelStorage` and `MelAgent` only see `MelSpec`; `MelSystem` sees nothing.
3. **Views import only `SwiftUI`, `MelSpec` and `UniformTypeIdentifiers`** (for `fileImporter` content types). Anything a view needs to do (copy, show in Finder, open Terminal, sign in) is a method on `AppState` or `SpecSession`. Views never touch `MelAgent`, `MelStorage` or `MelSystem`.
4. **Session depends on abstractions for the runner.** `SpecSession` gets an `any AgentRunning`; it never names `AgentRunner` or `ClaudeCode`.
5. **`MelApp` is the composition root**: it builds `ClaudeCode`, the `AgentRunner` factory and `AppState` (see `AppState.init`). Nothing else constructs `ClaudeCode` or `AgentRunner`.
6. Only what another module uses is `public`. Public structs get an explicit `public init`.
7. The app target turns on the `MemberImportVisibility` upcoming feature, so a file only sees members of modules it imports. Together with per-file imports, the only thing left to review for rule 3 is the import lines in `Mel/Views/`.

## MelSpec/Models.swift (core)

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
    case sessionNotFound              // --resume id unknown: SpecSession reruns fresh, never shown to the user
}

struct ActivityLine: Hashable, Identifiable {
    let id = UUID()
    var at: Date
    var text: String                  // "read specs/PRODUCT.md"
}

/// Whether Claude Code can be used. Lives here (not in MelAgent) so views can show it.
enum AgentStatus: Hashable {
    case checking
    case ready(executable: URL, version: String)
    case notSignedIn(executable: URL)
    case missing
    case broken(String)
}
```

## MelSpec/MarkdownParser.swift (core)

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

## MelSpec/Pipeline.swift, Prompt.swift (core)

```swift
extension DocKind {
    var next: DocKind? { get }                 // product → requirements → design → tasks → nil
}                                              // DocKind is also CodingKeyRepresentable

enum PipelineEvent: Hashable, Sendable {
    case discoveryFinished, draftFinished, draftStopped(StopReason), resume, finishByHand
    case approve(DocKind, assumptionsLeft: Int)
    case edited(DocKind)
}

extension Spec {
    /// Pure reducer: applies the event, or returns false and leaves the spec unchanged.
    @discardableResult mutating func apply(_ event: PipelineEvent) -> Bool
}

extension MarkdownParser {
    static func uncoveredCriteria(requirements: String, tasks: String) -> [String]
}

enum Prompt: String, CaseIterable, Sendable {  // MelSpec/Prompts/*.md (+ shared rules.md), Bundle.module
    case discovery, product, requirements, design, tasks, `continue`
    init(drafting kind: DocKind)
    func build(_ values: [String: String]) -> String   // single-pass {{key}} replacement
}
```

## MelStorage (core)

```swift
actor SpecStore {                              // one per spec folder; atomic writes
    init(folder: URL, debounce: Duration = .milliseconds(500))
    static func slug(_ name: String) -> String
    static func specsFolder(name: String, parent: URL) -> URL
    static func existingFiles(in folder: URL) -> [DocKind]
    static func create(_ spec: Spec) throws
    static func loadState(in folder: URL) throws -> Spec
    func read(_ kind: DocKind) -> String?
    func readAll() -> [DocKind: String]
    func write(_ text: String, for kind: DocKind) throws
    nonisolated func url(_ kind: DocKind) -> URL
    func saveState(_ spec: Spec)                // debounced .mel/state.json
    func flushState() throws
}

final class FileWatcher: Sendable {            // FSEvents; onChange on a background queue
    enum Resolution: Hashable, Sendable { case reload(String), conflict(fileText: String) }
    init(folder: URL, onChange: @escaping @Sendable (DocKind, String) -> Void)
    func noteWritten(_ text: String, for kind: DocKind)   // call before every Mel write
    static func resolve(fileText: String, editorText: String, savedText: String) -> Resolution
}

struct Library {                               // ordered folder bookmarks in UserDefaults
    struct Item: Hashable, Sendable { var isMissing: Bool /* … */ }
    init(defaults: UserDefaults = .standard, key: String = "library")
    func load() -> [Item]
    func save(_ folders: [URL])
}
```

## MelAgent/AgentTypes.swift (platform)

```swift
import Foundation

struct AgentRequest: Sendable {
    var prompt: String                // sent on stdin
    var workingDirectory: URL         // project folder (parent of specs/)
    var resumeSessionID: String?
    var persistSession: Bool          // false → --no-session-persistence
    var systemPrompt: String?         // stage contract → --append-system-prompt
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

`MelAgent/ClaudeCode.swift`: `struct ClaudeCode: AgentAdapter`. `MelAgent/AgentRunner.swift`: `actor AgentRunner: AgentRunning { init(adapter: any AgentAdapter, executable: URL, timeout: Duration = .seconds(120)) }`. `MelAgent/ShellPath.swift`: `enum ShellPath { static func loginPATH() async -> String; static func find(_ name: String, extraPaths: [String]) async -> URL? }`.

## MelSystem/ (platform)

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

    /// Composition root passes `ClaudeCode()` and `{ AgentRunner(adapter: ClaudeCode(), executable: $0) }`;
    /// tests and previews pass fakes.
    init(adapter: any AgentAdapter, makeRunner: @escaping @Sendable (URL) -> any AgentRunning)

    func scanForAgent() async
    func session(for id: Spec.ID) -> SpecSession
    func createSpec(name: String, idea: String, parentFolder: URL) throws -> SpecSession
    func removeFromLibrary(_ id: Spec.ID)
    func specFolder(name: String, parent: URL) -> URL   // shown in New Spec; SpecStore.specsFolder

    // System actions for views (views never import MelSystem)
    func signIn()                             // Terminal with the adapter's login command
    func copy(_ text: String)

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

    // Handoff / system actions for views
    var startCommand: String { get }                // claude "Read specs/ and implement TASKS.md, task 1"
    func showInFinder()
    func openStartCommandInTerminal()
    func finish(commitToGit: Bool) throws
    var canCommit: Bool { get }                     // Git installed; checkbox hidden otherwise
    var isGitRepository: Bool { get }              // false → commit asks before `git init`
    func updateIdea(_ idea: String)                 // "Your Idea › Edit…"

    static func preview(_ spec: Spec, documents: [DocKind: String] = [:], liveText: String = "", activity: [ActivityLine] = [], isRunning: Bool = false, lastError: String? = nil) -> SpecSession
}
```

`preview(…)` factories create inert instances (no disk, no agent) for SwiftUI previews. ui builds its preview data in `Mel/Views/Preview/` on top of them.
