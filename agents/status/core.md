# core status

Wave: 6, step 0 (contract v2 stubs) pushed, waiting for the orchestrator merge
Updated: 2026-11-23

## Done
- 2.1 `MelSpec/Pipeline.swift`: `PipelineEvent` + `Spec.apply(_:) -> Bool` (pure, returns false and leaves the spec unchanged for a disallowed event). Tests cover every transition, approval blocked by assumptions, and edit of an approved file → review without cascading.
- 2.2 `MelSpec/MarkdownParser.swift`: line-based `blocks`/`summary`, plus `uncoveredCriteria(requirements:tasks:)`. Tests use this repo's docs/REQUIREMENTS.md and TASKS.md (9 stories, 66 criteria, 41 tasks, all covered).
- 2.3 `MelStorage/SpecStore.swift`: actor per spec folder. Provides slug, specsFolder, existingFiles, create, atomic read/write, `loadState`, and `saveState` (debounced to 500 ms, latest wins) with `flushState`.
- 2.4 `MelStorage/FileWatcher.swift`: FSEvents file-level stream on the specs folder. It catches both atomic and in-place saves and only reports the four files when their text changed. `noteWritten` skips Mel's own writes, and `resolve(fileText:editorText:savedText:)` returns reload or conflict.
- 2.5 `MelStorage/Library.swift`: ordered bookmarks plus last path in UserDefaults. Bookmarks follow moved folders; a deleted or trashed folder loads as missing.
- 4.1 `MelSpec/Prompts/*.md` (discovery, product, requirements, design, tasks, continue, plus shared rules.md) and `Prompt.build(_:)`, a single-pass `{{key}}` replacement. Package.swift declares `.process("Prompts")`.
- Fix after review: FileWatcher's own-write race. `noteWritten` no longer overwrites `known`; own writes are kept as an ordered pending list per file and matched by content in `check()`. This also covers several quick writes in a row. New tests check before the write lands and cover rapid own writes.
- Second review fix: FileWatcher tests that depend on reports wait for them (the live FSEvents stream may report first). `noteWritten` skips text equal to the file. Full `xcodebuild … test` green 6 runs in a row (65 tests).

- Wave 2 contract stubs (ed94bba): `StopReason.sessionNotFound`, `AppState.missingFolders/locate/removeMissing/specFolder` (specFolder is real), `extraSearchPaths` persisted in UserDefaults (real; `init` takes an optional `defaults:` for tests), `SpecSession.conflict/resolveConflict/canCommit/isGitRepository/updateIdea` (canCommit, isGitRepository real), `preview(lastError:)`.

- 4.2–4.5, 4.8 (2567564). `SpecSession` is real: Discovery turns (`DiscoveryTurn.decode`, unreadable reply → `lastError` + `retry()`), Draft Now (open question → "You decide", uncovered topics → decide list), drafting (preview 10/s, file every 500 ms, plan line stripped, final trim + newline), review (`save` debounced 500 ms, confirm/change assumption, approve blocked by assumptions then drafts the next file, Keep Mine / Use File), recovery (`stop`, `resume` truncates to the last complete `##` and continues with `--resume`; an unknown session redrafts from scratch; usage limit with future `resetsAt` notifies and waits), `finishByHand`, one run at a time via `runningSpecID`. `AppState` restores the library (missing → `missingFolders`; a spec saved mid-draft loads as stopped), caches sessions, `createSpec`, `locate`, `removeMissing`, `removeFromLibrary`, `scanForAgent`, `signIn`. Also real: `finish(commitToGit:)`, `showInFinder`, `openStartCommandInTerminal`, `updateIdea`.
- Pure helpers in MelSpec: `DiscoveryTurn`, `Spec.answersText/coverageText/decideText`, `DraftText` (plan strip, truncate, assumption edits). The "Done when" test (`MelTests/Session/SpecSessionTests`) drives idea → 4 approved files with a fake `AgentRunning`, including stop and resume. Full suite green 3 runs in a row.

- Flaky SpecSessionTests fixed: the crash report showed `FileWatcher` was retained during its own deinit. The FSEvents callback used `takeUnretainedValue` on the watcher while main dropped the last SpecSession. The stream now owns a separate `Core`, and deinit drains the queue first. Not caused by UserDefaults suites (each test uses a unique one) or by notifications (stubbed).
- Notifications: `AppState.notify` / `authorizeNotifications` hooks (Notifier by default); permission requested once before the first run; posts on draft finished, failure stop (not user Stop, not sessionNotFound), Discovery failure, usage-limit reset. `finish()` uses `Git.specPaths`. `preview(…, conflict:)`.

- 5.1 `MelTests/Session/EndToEndTests.swift`: the real `AgentRunner` + `ClaudeCode.parse` + disk, with `fake-claude.sh` replaying scripted fixtures in `MelKit/Tests/MelAgentTests/Fixtures/e2e/` (README there). It covers idea → 4 approved files with a real Stop (SIGINT to the `hang` process) and `--resume` with the right session id, one run at a time across two specs, and the recorded unknown-resume run → fresh redraft with no notification. About 0.1 s per test after the runner's one login-shell PATH read.
- Found by 5.1: `AppState` built a new `AgentRunner` per run, so every Discovery turn and draft re-ran `$SHELL -l -i`. It now keeps one runner per executable.

- Debug bundle id `com.kaanf.mel.debug` (5cdeebf), Release unchanged; test-host change skipped as decided. Verified with `xcodebuild build` only (built Info.plist shows the debug id); the test run waits for the end of the install test.

- Wave 4 model + prompts (4.9): `Answer.text`, `CoverageItem.phase` (decoder defaults a missing phase to `.product`; init defaults to `.product` so previews compile), `DiscoveryTurn` takes empty or missing `options` (open question), `coverageText` = `- Label (phase): state`, `answersText` renders free text (extra lines indented). discovery.md: phases in file order, open question first per phase, new topics only current/later phase, UX in Design; sample reply decodes (tested). design.md: 7 sections, `1. User experience` first. DiscoveryView `answerText` got a minimal `.text` case so main compiles; ui owns the real card. Repo-doc counts: criteria 69. Full suite green 2 runs.

- Wave 5 (5.5): Sparkle 2.10.1 (exactVersion, newest 2.x ≥ 2 weeks old) on the `Mel` target only; `Package.resolved` committed. `Mel/Info.plist` (excluded from the synchronized folder via an exception set, merged into the generated plist through `INFOPLIST_FILE`) holds `SUFeedURL`, `SUEnableAutomaticChecks`, `SUPublicEDKey` (from platform). `MARKETING_VERSION` 0.2. MarkdownParserTests: criteria 71, tasks 42. Checked a Developer ID archive + export (no notarization): app, Sparkle.framework, Autoupdate, Updater.app, Downloader/Installer.xpc all Developer ID + runtime; `codesign --verify --deep --strict` ok. Full suite green 2 runs.

- Wave 5 follow-up: `SUEnableAutomaticChecks` = `$(SPARKLE_AUTOMATIC_CHECKS)` (Debug NO, Release YES), so a Debug build (build 1) never offers to replace itself with the Release DMG. Sparkle 2.10.1 reads a string bool (`convertObjectToBoolNumber` in SUHost.m). Built plists checked; full suite green 2 runs.

- v0.2.1: `MARKETING_VERSION` 0.2.1 on all targets. Full suite green 2 runs.

## In progress
- Wave 6 step 0 done: v2 contract stubs on agent/core (API below). Waiting for the merge + CONTRACTS.md update.

## Next
- After the merge: v2 reducer (sizes, analyze, edited/stale, revise), V2.md §6 parser (open questions, decisions, tasks, modules), SpecStore layout bodies (§3, snapshots, DECISIONS.md, scan, attachments, task prompts), ProjectStore bodies, prompts (project context, one-shot intake, files with step markers + round-2 trailer, revise, analyze, impact), SPEC-FORMAT.md rewrite. Tests. Never touch com.kaanf.mel defaults or /Applications/Mel.app.

## Notes
- `SpecSession` holds `AppState` weakly; tests keep the AppState alive. `AppState.init` takes `defaults:` (tests pass a throwaway suite; previews use suite "preview" and never save the library).
- `changeAnswer` only records the new answer; it does not drop later questions. The next turn sees it.
- A run refused because another spec is running (or Claude Code isn't ready) sets `lastError`; during drafting the file goes to `stopped(kind, .user)` so Continue Drafting works.
- `DocKind` is now `CodingKeyRepresentable`, so `docs` encodes as a JSON object in state.json, e.g. `"product" : "locked"`.
- `Spec.init` has defaults for a new spec (stage `.discovery`, the size's files locked). `DocKind.next`/`allLocked` are gone: use `size.file(after:)` / `size.allLocked`.
- Step 0 transition (v1 code still runs): v1 `createSpec(name:idea:parentFolder:)` makes Product-size specs, so the v1 flow drafts 5 files; EXPERIENCE/ARCHITECTURE use the v1 design.md template and SPEC uses requirements.md until the v2 prompts land. discovery.md's `design` phase is now `experience`. The v1 discovery fixture test checks only the stream shape (its JSON says `design`). v1 state.json no longer decodes (v1 specs dropped, OK'd by orchestrator).
- `summary(_:kind:)` leaves `uncoveredCriteria` empty because it needs both files. In Wave 2, SpecSession fills it for `.tasks` from `uncoveredCriteria(requirements:tasks:)`.
- Placeholders. discovery: name, idea, answers, coverage. product: name, idea, answers, decide. requirements and design: those plus approved. tasks: name, idea, decide, approved. continue: file, partial. Session formats answers, coverage, decide and approved as Markdown text in Wave 2.
- FileWatcher's `onChange` runs on a background queue, so Session must hop to the main actor. Call `noteWritten` before every write Mel makes; each call adds a pending text, which is cleared when that text (or a newer own write) shows up on disk.
- `Library` isn't Sendable (UserDefaults); use it from AppState on the main actor.
- Wave 2 still needs pure helpers in MelSpec: plan-line strip, truncate to the last complete `##`, assumption confirm/change text edits, and discovery JSON decoding.

## Blocked
- (nothing)

## Requests to orchestrator
Step 0 is on agent/core: build + full suite green, no warnings. Stub bodies are `fatalError("stub")`, except parsers a preview might call (`OpenQuestion.parse`, `SpecTask.parse`, `Decision.parse`, `ProjectContext.modules`), which return `[]`. Outside core's area I only made mechanical edits so main builds: `.design` → `.architecture` in views/previews, `edited`/`stale` added to switches (AgentStatusBadge, FailureSheet, MainView), `.analyze` in SidebarItem. v1 views still iterate `DocKind.allCases` (6 rows); ui replaces them with `spec.size.files`.

Public API diff for CONTRACTS.md:

```swift
// MelSpec / Models.swift
public struct Spec {                                   // + size, buildsOn, attachments, analyze, analysis
    public var size: SpecSize
    public var folder: URL                             // now <project>/specs/<slug>/
    public var buildsOn: [String]                      // B1 chips: module names or "Something new"
    public var attachments: [Attachment]
    public var analyze: AnalyzeStatus
    public var analysis: AnalyzeResult?
    public var project: URL { get }                    // folder/../..
    public init(id: UUID = UUID(), name: String, idea: String, size: SpecSize = .product, folder: URL,
                stage: Stage = .discovery, docs: [DocKind: DocStatus]? = nil /* size.allLocked */,
                questions: [Question] = [], coverage: [CoverageItem] = [], buildsOn: [String] = [],
                attachments: [Attachment] = [], analyze: AnalyzeStatus = .locked,
                analysis: AnalyzeResult? = nil, sessionID: String? = nil)
}
public enum SpecSize: String, Codable, CaseIterable { case quickFix, feature, product
    var files: [DocKind]                               // [.spec] · [.requirements, .architecture, .tasks] · [.product, .requirements, .experience, .architecture, .tasks]
    var intakeQuestions: Int                           // 2 · 3 · 5
    var hasAnalyze: Bool                               // false for quickFix
    var needsProject: Bool                             // false for product (A4x)
    func file(after: DocKind) -> DocKind?
    var allLocked: [DocKind: DocStatus]
}
public enum DocKind { case product, requirements, experience, architecture, tasks, spec   // - design, - next, - allLocked
    var draftSteps: [String]                           // B3 checklist (stub: [])
}
public enum Stage { … + case analyze }                 // discovery, drafting, review, stopped, analyze, done
public enum DocStatus { … + case edited, stale }       // locked, writing, stopped, review, approved, edited, stale
public enum AnalyzeStatus: Codable, Hashable { case locked, running, issues(Int), passed, stale }
public enum QuestionRound: Int, Codable { case intake = 1, draft = 2 }
public struct Question { + public var round: QuestionRound   // init(…, shapes:, round: = .intake, options:, answer:) }
public struct Attachment: Codable, Identifiable, Hashable { public var fileName: String; id = fileName }

// MelSpec / Analysis.swift
public struct OpenQuestion: Identifiable, Hashable { kind: DocKind, index: Int, text: String; id "kind-index"
    static func parse(_ text: String, kind: DocKind) -> [OpenQuestion] }
public struct AnalyzeResult: Codable, Hashable {
    var stats: [Stat]                                  // Stat { value: String, label: String }
    var issues: [Issue]                                // Issue { id, kind: IssueKind, location, text, actions: [Action] } (2 actions, 2nd is primary)
    var coverage: [CoverageRow]                        // CoverageRow { id "1.3", text, screen: Mark?, architecture, task, test: Mark }
    enum IssueKind: String { case contradiction, noTask, qualityNotCovered, scopeCreep }
    struct Action { label: String, fix: String, files: [DocKind] }
    enum Mark: String { case covered, missing, conflict }
    static func decode(_ reply: String) throws -> AnalyzeResult
}
public struct ImpactResult: Codable, Hashable { var items: [Item]   // Item { kind: DocKind, what: String, count: String }
    static func decode(_ reply: String) throws -> ImpactResult }

// MelSpec / Decision.swift
public struct Decision: Codable, Identifiable, Hashable { id "D-07", title, reason, source, date: Date, replaces: String?, affects: [String]
    static func nextID(after: [Decision]) -> String
    static func markdown(_ decisions: [Decision]) -> String
    static func parse(_ text: String) -> [Decision] }

// MelSpec / ProjectContext.swift
public struct ProjectContext: Codable, Hashable { product, tech, structure, principles: String
    static let fileNames: [String]                     // product.md tech.md structure.md principles.md
    var modules: [Module]                              // structure.md "## Modules" (- Name — path)
    static func decode(_ reply: String) throws -> ProjectContext }
public struct Module: Codable, Hashable { name: String, path: String }
public struct Project: Identifiable, Hashable { folder: URL, isMissing: Bool, hasContext: Bool; id = folder; name = folder.lastPathComponent }

// MelSpec / Handoff.swift
public struct SpecTask: Identifiable, Hashable { number: Int, title, priority: String, covers: [String], reads: String, verify: String, parallelWith: [Int]; id = number
    static func parse(_ tasks: String) -> [SpecTask]
    var promptFileName: String                         // task-01.md
    func prompt(requirements: String) -> String }

// MelStorage / SpecStore (actor, folder = <project>/specs/<slug>/)
static func specFolder(slug: String, project: URL) -> URL
static func scan(project: URL) -> [Spec]               // specs/*/.mel/state.json
func snapshot(_ kind: DocKind) -> String?              // .mel/approved/<FILE>.md
func saveSnapshot(_ text: String, for kind: DocKind) throws
func readDecisions() -> [Decision]                     // DECISIONS.md
func writeDecisions(_ decisions: [Decision]) throws
func attach(copying file: URL) throws -> Attachment    // .mel/attachments/
func attachLog(_ text: String) throws -> Attachment    // log-N.txt
func remove(_ attachment: Attachment) throws
nonisolated func url(_ attachment: Attachment) -> URL
func writeTaskPrompts(_ tasks: [SpecTask], requirements: String) throws -> [URL]   // prompts/task-NN.md
// kept for v1 until wiring: specsFolder(name:parent:)

// MelStorage / ProjectStore (enum, new)
static func contextFolder(project: URL) -> URL         // .mel/project/
static func readContext(project: URL) -> ProjectContext?
static func writeContext(_ context: ProjectContext, project: URL) throws
static func addRule(_ rule: String, project: URL) throws
static func isEmpty(project: URL) -> Bool              // A3 "New project, no code yet"
static func createProject(name: String, parent: URL) throws -> URL
// Library: unchanged API; v2 stores project folders (AppState will use a new key, so v1 entries drop out)

// Mel / AppState (+)
var projects: [Project]
private(set) var contexts: [Project.ID: ProjectContext]
private(set) var foundRepositories: [URL]              // A2
private(set) var projectSetup: ProjectSetup?           // A3
func specs(in project: Project) -> [Spec]
func findRepositories() async
@discardableResult func addProject(_ folder: URL) throws -> Project
@discardableResult func createProject(name: String, parent: URL) throws -> Project
func removeProject(_ project: Project)
func setUpProject(_ project: Project) async
func addRule(_ rule: String, to project: Project) throws
func showContext(of project: Project)
func createSpec(name: String, idea: String, size: SpecSize, project: Project?, buildsOn: [String] = [], files: [URL] = [], logs: [String] = []) throws -> SpecSession
static func preview(_ specs: [Spec], agent: AgentStatus, projects: [Project] = [], contexts: [Project.ID: ProjectContext] = [:], foundRepositories: [URL] = [], projectSetup: ProjectSetup? = nil) -> AppState
struct ProjectSetup: Hashable { project: Project, isNewProject: Bool, isRunning: Bool, activity: [ActivityLine], context: ProjectContext?, lastError: String? }

// Mel / SpecSession (+)
private(set) var draftStep: Int                        // B3
private(set) var impact: ImpactResult?                 // C1
private(set) var snapshots: [DocKind: String]          // C1 diff / Undo
private(set) var decisions: [Decision]
currentQuestion / answeredQuestions                    // now round 1 only
func followUpQuestions(for kind: DocKind) -> [Question]   // round 2, unanswered
func openQuestions(in kind: DocKind) -> [OpenQuestion]
var tasks: [SpecTask]                                  // B7
func attach(_ files: [URL]) async throws
func attachLog(_ text: String) async throws
func removeAttachment(_ attachment: Attachment) async throws
func answerFollowUp(questionID: String, _ answer: Answer) async      // → revise
func answerOpenQuestion(_ question: OpenQuestion, _ answer: String) async   // → revise
func analyze() async
func fixIssues() async                                 // each issue's primary action, then Analyze again
func apply(_ action: AnalyzeResult.Action) async
func handOffAnyway()
func saveDecision(title: String, reason: String, for kind: DocKind) async throws
func undoEdit(_ kind: DocKind) async
func refine() async
func keepAsIs()
func resumeLater()                                     // C2
func writeTaskPrompts() async throws -> [URL]
func writeAgentsMD() throws
static func preview(_ spec: Spec, documents:, liveText:, activity:, isRunning:, lastError:, conflict:,
                    draftStep: Int = 0, impact: ImpactResult? = nil, snapshots: [DocKind: String] = [:], decisions: [Decision] = []) -> SpecSession
```

Points to check: `Stage.analyze` covers B6 both while running and with results (`spec.analyze` tells which). C1 isn't a stage: it shows when a file is `edited`. Revise runs reuse `Stage.drafting(kind)`. `writeAgentsMD` will call platform's marker-block writer.

## Questions for the user
- (none)
