# Design

Guiding rule: **performance, speed and the least complexity that works.** No speculative abstractions, no fallback layers, no dependencies unless essential. When something here starts to grow, cut scope before adding machinery.

Deferred (see REQUIREMENTS.md › Later): Codex, following the coding agent's progress, time estimates, parallel spec runs. One spec runs at a time across the app (`AppState.runningSpecID`); reading a project's context may run next to it.

## 1. Architecture

### Stack

| Concern | Choice |
|---|---|
| Language | Swift 6, strict concurrency |
| UI | SwiftUI; AppKit only where SwiftUI can't (`NSWorkspace`, `NSOpenPanel`, `NSPasteboard`) |
| State | Observation (`@Observable`) |
| Concurrency | async/await, `AsyncStream`, `Task` cancellation |
| Processes | Foundation `Process` + `Pipe` |
| Persistence | One Codable JSON file per spec (`specs/<slug>/.mel/state.json`) + `UserDefaults` for app settings and the library |
| Markdown | Own small line-based parser for our fixed format; `AttributedString(markdown:)` for inline styling. **No dependencies.** |
| Notifications | `UserNotifications` |
| Updates | Sparkle 2 (the only third-party dependency; app target only, decided 2026-11-23) |
| Logging | `os.Logger` |
| Tests | Swift Testing |
| Minimum OS | macOS 26 |

### Distribution

The app launches the user-installed `claude` CLI, which reads `~/.claude` and needs network access. A sandboxed app's child processes inherit the sandbox, so the CLI would not work. Therefore:

- **Not sandboxed**, Hardened Runtime, Developer ID signed, notarized and stapled, shipped as a **DMG**.
- `scripts/release.sh`: `xcodebuild archive` → export (Developer ID) → `notarytool submit --wait` → `stapler staple` → `hdiutil create` DMG → notarize + staple the DMG.
- No Mac App Store.
- **Updates: Sparkle 2.** Feed `https://raw.githubusercontent.com/kaanf/mel/main/appcast.xml` (latest release only), DMG enclosure from the GitHub release. Updates are signed with an EdDSA key (private key in the release Mac's login Keychain, backed up by the user; public key `SUPublicEDKey` in Info.plist). Sparkle compares `CFBundleVersion`: `release.sh` sets it to `git rev-list --count HEAD`, so every release from `main` is higher. `release.sh` ends with `sign_update` on the notarized DMG and writes `appcast.xml`; it is committed after `gh release create`. Automatic daily checks are on by default (`SUEnableAutomaticChecks`), no system profile is sent.
- Sparkle is imported only in `App/` (`SPUStandardUpdaterController`); views get plain values and closures.

### Project layout

Layers are modules: one app target for the UI and session objects, one local Swift package (`MelKit`) for everything below. The compiler enforces the dependency direction; no third-party code.

```
Mel.xcodeproj
├── Mel/                 app target (default isolation MainActor)
│   ├── App/             MelApp: scenes, commands, composition root
│   ├── Views/           one folder per screen, Components/, Preview/   → SwiftUI, MelSpec, UTI
│   └── Session/         AppState, SpecSession                         → all MelKit modules
├── MelTests/Session/
├── MelKit/              local package (nonisolated by default)
│   ├── Sources/MelSpec/     domain: models, the board's pipeline, patches, Markdown parser, Prompts/
│   ├── Sources/MelStorage/  spec folder I/O, state.json, library, file watcher   → MelSpec
│   ├── Sources/MelAgent/    Claude Code adapter, AgentRunner, ShellPath           → MelSpec
│   ├── Sources/MelSystem/   Terminal, Finder, pasteboard, Git, notifications
│   └── Tests/               one Swift Testing target per module; MelAgentTests/Fixtures/
└── scripts/release.sh
```

Rule: `MelSpec` stays pure (no I/O, no SwiftUI) so the pipeline is unit-testable. Full dependency rules below.

### Project conventions

- Xcode project `Mel.xcodeproj`, shared scheme `Mel`. The app target `Mel` holds only `App/`, `Views/`, `Session/`; its test target `MelTests` holds `Session/` tests.
- Everything below the UI lives in one local Swift package, **`MelKit/`** (`swift-tools-version: 6.2`, `.macOS(.v26)`), referenced by the project. Its library targets are the modules; its test targets are Swift Testing. No third-party dependencies (the only one in the project is Sparkle 2, app target only).
- The `Mel` scheme runs **all** tests (app + every MelKit test target), so the one `xcodebuild … test` command in CLAUDE.md stays the only command.
- App targets use synchronized folders (`PBXFileSystemSynchronizedRootGroup`): adding a file never changes `project.pbxproj`. Don't add `.gitkeep` files (each needs a pbxproj exception, otherwise "Multiple commands produce .gitkeep"); a folder shows up with its first real file.
- Bundle identifier `com.kaanf.mel`. Hardened Runtime on. **No App Sandbox.**

#### Isolation

- App target: Xcode defaults, **default actor isolation `MainActor`**, approachable concurrency. `AppState`, `SpecSession` and views are main-actor.
- MelKit targets: the package default (**nonisolated**), Swift 6 language mode. Types are plain values, actors or `Sendable`; no `nonisolated` markers needed. Nothing in MelKit is `@MainActor`.

#### Layers and dependencies

Dependencies point one way, toward `MelSpec`. The compiler enforces it through the package's target dependencies; the import rule for app folders is checked in review.

```
MelKit/                        (local package)
├── Sources/
│   ├── MelSpec/                domain: Models, Board, Change, Analysis, MarkdownParser, Prompts/ (*.md resources)  → Foundation only
│   ├── MelStorage/             SpecStore, Library, FileWatcher                                     → MelSpec
│   ├── MelAgent/               AgentTypes, ClaudeCode, AgentRunner, ShellPath                      → MelSpec
│   └── MelSystem/              SystemActions, Git, Notifier                                        → (none)
└── Tests/
    ├── MelSpecTests/ MelStorageTests/
    └── MelAgentTests/ (+ Fixtures/) MelSystemTests/
Mel/                           (app target)
├── App/               MelApp (composition root), Updater  → may import everything, the only place that imports Sparkle
├── Session/           AppState, SpecSession       → MelSpec, MelStorage, MelAgent, MelSystem
└── Views/             screens, Components/, Preview/  → SwiftUI, MelSpec, UniformTypeIdentifiers
MelTests/Session/
```

Rules:

1. **MelKit modules never import SwiftUI or AppKit**, except `MelSystem`, which may use AppKit for `NSWorkspace`/`NSPasteboard`. `MelSpec` does no I/O beyond reading its own bundled prompt resources.
2. **Modules don't know each other sideways.** `MelStorage` and `MelAgent` only see `MelSpec`; `MelSystem` sees nothing.
3. **Views import only `SwiftUI`, `MelSpec` and `UniformTypeIdentifiers`** (for `fileImporter` content types). Anything a view needs to do (copy, show in Finder, open Terminal, sign in) is a method on `AppState` or `SpecSession`. Views never touch `MelAgent`, `MelStorage` or `MelSystem`.
4. **Session depends on abstractions for the runner.** `SpecSession` gets an `any AgentRunning`; it never names `AgentRunner` or `ClaudeCode`.
5. **`MelApp` is the composition root**: it builds `ClaudeCode`, the `AgentRunner` factory and `AppState` (see `AppState.init`). Nothing else constructs `ClaudeCode` or `AgentRunner`.
6. Only what another module uses is `public`. Public structs get an explicit `public init`.
7. The app target turns on the `MemberImportVisibility` upcoming feature, so a file only sees members of modules it imports. Together with per-file imports, the only thing left to review for rule 3 is the import lines in `Mel/Views/`.

### Runtime overview

```
SwiftUI views ──observe──▶ SpecSession (@Observable, @MainActor), one per open spec
                                │ answerCard · tell · removeStory · save · resumeBoard · startBuilding
                                ▼
                 Spec.nextStep (MelSpec, pure) ──▶ draft(file) | change | check | nil (waits for the user)
                                │
                                ▼
                     AgentRunner (actor) ──▶ claude -p … (Process)
                                │ text deltas, or one JSON reply
                                ▼
          draft: stream into the file (debounced)      change: Change.apply places {old, new} edits
```

**Mel is the only writer of the spec files.** Claude Code runs without write or shell tools. A draft streams plain Markdown that Mel appends to the file; every later change comes back as edits that Mel places.

`AppState` (one per app) holds the agent's status, the library (projects, their context, specs), the current project and the sessions. `AgentAdapter` is a small protocol with one implementation (`ClaudeCode`) so Codex can be added later.

## 2. Data model

The types are in `MelKit/Sources/MelSpec/` (`Models.swift`, `Board.swift`, `Analysis.swift`, `Change.swift`, `Decision.swift`, `ProjectContext.swift`, `Tokens.swift`). The shape that matters:

```swift
struct Spec {
    let id: UUID
    var name, idea: String
    var size: SpecSize               // quickFix | feature | product: fixes the files and their order
    var folder: URL                  // <project>/specs/<slug>/
    var stage: Stage                 // discovery (intake) | board | done
    var docs: [DocKind: DocStatus]   // locked, writing, stopped, approved (written), edited, stale
    var questions: [Question]        // intake, a draft's questions, open questions left in a file
    var analyze: AnalyzeStatus       // the check after the last file
    var analysis: AnalyzeResult?     // coverage by ID + contradictions; its issues are cards
    var halted: Halt?                // the agent stopped; nothing runs until Resume
    var unplacedChange: UnplacedChange?   // waits for "Rewrite FILE" or Cancel
    var removedStories: [RemovedStory]?   // for Restore
    var tokens: [TokenStep: Int]?    // per step, from result.usage
    var build: BuildState?           // building | done, after the handoff
    var fillGaps: Bool, language: SpecLanguage?, attachments: [Attachment], sessionID: String?
}
```

- A `Card` is what the inbox shows: built from a `Question` or from a check issue, answered with an `Answer` (`option`, `text`, or `agentDecides` for a guess).
- The whole `Spec` is saved to `.mel/state.json` on every change (debounced, atomic). No database. The library is an array of project folders in `UserDefaults`; specs are found by scanning.
- State from before 0.5 still loads: a lane stage (`drafting`, `review`, `stopped`, `analyze`) decodes as `board`, and the doc status `review` counts as written.
- App settings are `UserDefaults` keys read with `@AppStorage`: `fillGaps`, `showTokens`, `showSidebarFiles`, `commitSpec`, `writeAgentsFile`, `settingsTab`, `didShowWelcome`; `AppState` keeps `currentProject`, `editorApp`, `specLanguage`, `extraSearchPaths`, `projects`.

## 3. Key flows

### The board's pipeline

Pure, in `MelSpec/Board.swift`. `Spec.nextStep` says what to run; mutating functions record what happened. `SpecSession.runBoard` loops until `nextStep` is nil.

```
discovery ──every intake question answered | Skip──▶ board
board:  nextStep =
          nil       while a card is open, an edit waits for Update / Keep, a change is unplaced, or the agent is halted
          change    answers were given since the files were written: one patch run for all of them
          draft(f)  the next file not written yet (or the one that was cut off)
          check     every file is written and the check hasn't run (not for a Quick fix)
          nil       → isReady: Start Building is enabled
board ──Start Building──▶ done
```

No file is approved. The gate is the inbox: a file starts only when no card of the written files is open; "Write it now" turns open cards into guesses (`agentDecides`) with no run.

### Drafting

1. Build the prompt (`Prompts/<kind>.md`): project context, idea, answers, the files written before, attachment paths.
2. Run `claude -p` with read-only tools and a stored session.
3. Append text deltas to a buffer; write the file at most every 500 ms (atomic); the open file's preview updates at most 10 times a second.
4. On finish: strip the markers, write the file, save its snapshot (`.mel/approved/`), turn the draft's trailer questions and `[!OPEN QUESTION]` callouts into cards.

### Changes

Tell Mel, card answers, Update after an edit, Remove and Restore all run `Prompts/change.md` once over the written files, without tools unless the request has attachments. The reply is a `Change` (`{file, old, new}` edits). `Change.apply` places every edit or none.

- Placed: files are written, snapshots saved, Mel's own checks by ID rerun for free, and the result line carries what Undo needs.
- Not placed: nothing changes. `Spec.unplacedChange` keeps the edits; "Rewrite FILE" streams that one file whole (`Prompts/rewrite.md`), the only whole-file rewrite, then the edits that did fit go in.
- Free, no run: `Story.move` (scope), `StoryRemoval` (what a story takes with it), `Spec.writeNow`.

### Stop and resume

- **Stop**: `SIGINT`, then `SIGTERM` after 3 s. A cut-off draft is already on disk; `Spec.halt` records the reason and the file.
- **Resume**: the cut-off file is truncated to its last complete `##` section and continued with `--resume <sessionID>` (`Prompts/continue.md`); an unknown session writes it again from the start. A stopped change or check simply runs again.
- **Usage limit**: Resume waits for `resetsAt` and posts a notification then. No automatic runs.
- A board that was working when Mel quit is halted at load, so nothing runs on launch.

### Edits by hand

- The file editor saves on change (debounced, atomic). `FileWatcher` sees edits made elsewhere: no unsaved text in Mel → reload; otherwise ask "Keep Mine / Use File". No merge.
- An edit to a written file marks it `edited` and the files after it `stale`; the banner settles it: Update (one change run with the diff against the snapshot), Keep, or Undo (the snapshot goes back).

### Project context

`AppState.readContext(of:)`: one read-only run over the repo returns four Markdown files as JSON (`ProjectContext`), written to `.mel/project/`. It starts in the background after Start and from Settings › Specs › Read Again. Every spec prompt includes the files when they exist; a spec started before they do says "(no project context yet)" and the agent reads the repo itself.

### Detection

Read the login-shell `PATH` once per scan, add the extra search paths, find `claude`, run `claude --version`, check auth. Details in [AGENT-INTEGRATION.md](AGENT-INTEGRATION.md).

## 4. Interfaces

```swift
protocol AgentAdapter: Sendable {
    func detect(extraPaths: [String]) async -> AgentStatus       // ready / notSignedIn / missing / broken
    func loginCommand(executable: URL) -> String
    func arguments(for request: AgentRequest) -> [String]
    func environment(path: String) -> [String: String]
    func parse(line: Substring) -> [AgentEvent]                   // one NDJSON line
}

enum AgentEvent { case session(String), text(String), step(String), rateLimit(allowed: Bool, resetsAt: Date?), usage(tokens: Int), done(result: String), failed(StopReason) }

protocol AgentRunning: Sendable {                                 // AgentRunner; tests use a fake
    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error>
    func stop() async
}
```

System integration:

| Action | How |
|---|---|
| Open Terminal with a command | Write a temporary `.command` script and `NSWorkspace.open` it. No Apple Events entitlement or permission prompt |
| Show in Finder | `NSWorkspace.shared.activateFileViewerSelecting` |
| Copy | `NSPasteboard.general` |
| Open in Editor | `NSWorkspace.open`, with the app chosen in Settings › Specs or the Mac's default |
| Git commit | `/usr/bin/git` via `Process`; skipped if git is unavailable |
| Notifications | `UNUserNotificationCenter` |

## 5. Performance

- Never block the main actor: process I/O, file writes and Markdown parsing run off it.
- Read stdout in chunks and split lines in the runner; don't decode JSON on the main actor.
- Throttle UI updates from the stream (~10/s) and debounce disk writes (500 ms).
- Parse Markdown once per change into blocks, off the main actor.
- Tokens are a budget (OQ #24): a change is a patch, never a rewrite; scope moves, guesses and coverage checks cost no run.
- Launch fast: no work at launch except restoring the library; detection runs in the background.

## 6. Security and privacy

- Mel's only network call is Sparkle's update check (the appcast, then the DMG when the user agrees). No telemetry, no system profile.
- Claude Code runs with write and shell tools disabled, working directory = the project folder.
- Never overwrite a user's edit; never change a Ready file without a user action: a card answer, Tell Mel, Remove, Update or Rewrite (OQ #29).
- Prompts and history stay in the spec folder.
- `.mel/` is never committed: the spec commit excludes it by pathspec; `.gitignore` is left alone.
- A user-chosen executable must exist, be executable and answer `--version`.

## 7. Testing

- Unit (MelKit): the board's pipeline (`BoardTests`), patches and changes, coverage by ID, the Markdown parser, prompts against their sample replies.
- Agent: parse recorded NDJSON fixtures (success, usage limit, signed out, crash); runner tests with a fake `claude` shell script (stop, timeout).
- Session (`MelTests`): `BoardSessionTests` drive `SpecSession` with scripted replies; `EndToEndTests` run the real `AgentRunner` and parsing against `fake-claude.sh`.
- `#Preview` for every screen state using fixtures.
- Before each release: real Claude Code run, installed from the notarized DMG on a clean account.
