# Design

Guiding rule: **performance, speed and the least complexity that works.** No speculative abstractions, no fallback layers, no dependencies unless essential. When something here starts to grow, cut scope before adding machinery.

Deferred to a later version (see REQUIREMENTS.md › Later): Pause/Resume, "Ask for changes" with suggestions, Review inspector/History, time estimates, parallel runs. Only one agent run at a time across the app: `AgentRunner` is a single shared instance.

## 1. Architecture

### Stack

| Concern | Choice |
|---|---|
| Language | Swift 6, strict concurrency |
| UI | SwiftUI; AppKit only where SwiftUI can't (`NSWorkspace`, `NSOpenPanel`, `NSPasteboard`) |
| State | Observation (`@Observable`) |
| Concurrency | async/await, `AsyncStream`, `Task` cancellation |
| Processes | Foundation `Process` + `Pipe` |
| Persistence | One Codable JSON file per spec (`specs/.mel/state.json`) + `UserDefaults` for app settings and the library |
| Markdown | Own small line-based parser for our fixed format; `AttributedString(markdown:)` for inline styling. **No dependencies.** |
| Notifications | `UserNotifications` |
| Logging | `os.Logger` |
| Tests | Swift Testing |
| Minimum OS | macOS 26 |

### Distribution

The app launches the user-installed `claude` CLI, which reads `~/.claude` and needs network access. A sandboxed app's child processes inherit the sandbox, so the CLI would not work. Therefore:

- **Not sandboxed**, Hardened Runtime, Developer ID signed, notarized and stapled, shipped as a **DMG**.
- `scripts/release.sh`: `xcodebuild archive` → export (Developer ID) → `notarytool submit --wait` → `stapler staple` → `hdiutil create` DMG → notarize + staple the DMG.
- No Mac App Store. Sparkle updates post-MVP.

### Project layout

One app target, one test target. Folders, not modules. Split into a package only if build times or reuse demand it.

```
Mel.xcodeproj
├── Mel/
│   ├── App/            MelApp, scenes, AppState
│   ├── Agent/          ClaudeCode (detect, run, parse), AgentRunner
│   ├── Spec/           models, pipeline reducer, Markdown parser, prompts
│   ├── Storage/        spec folder I/O, state.json, library, Git
│   └── Views/          one folder per screen
├── MelTests/
│   └── Fixtures/       recorded Claude Code NDJSON output
└── scripts/release.sh
```

Rule: `Spec/` stays pure (no I/O, no SwiftUI) so the pipeline is unit-testable.

### Runtime overview

```
SwiftUI views ──observe──▶ SpecSession (@Observable, @MainActor), one per open spec
                                │ start · answer · stop · approve
                                ▼
                     AgentRunner (actor) ──▶ claude -p … (Process)
                                │ text chunks
                                ▼
                     SpecFile: append to buffer → write file (debounced)
```

**Mel is the only writer of the spec files.** Claude Code runs without write/shell tools and streams plain Markdown on stdout; Mel appends it to the file. No output parsing is needed for drafting; JSON is used only for Discovery questions.

`AgentAdapter` is a small protocol with one implementation (`ClaudeCode`) so Codex can be added later. No other abstraction for it now.

## 2. Data model

```swift
struct Spec: Codable, Identifiable {
    let id: UUID
    var name: String                 // "Yoga Studio Booking"
    var idea: String
    var folder: URL                  // …/yoga-studio-booking/specs
    var fillGaps: Bool
    var stage: Stage
    var docs: [DocKind: DocStatus]
    var questions: [Question]
    var coverage: [CoverageItem]
    var sessionID: String?           // Claude Code session, for resume
}

enum DocKind: String, Codable, CaseIterable { case product, requirements, design, tasks }
enum Stage: Codable { case discovery, drafting(DocKind), review(DocKind), stopped(DocKind, StopReason), done }
enum DocStatus: String, Codable { case locked, writing, stopped, review, approved }

struct Question: Codable, Identifiable {
    let id: String
    var title: String, why: String, shapes: DocKind
    var options: [Option]
    var answer: Answer?
}
struct Option: Codable { var label: String; var note: String; var suggested: Bool }
enum Answer: Codable { case option(Int, note: String?), decideLater }
struct CoverageItem: Codable { var label: String; var state: CoverageState }
enum CoverageState: String, Codable { case covered, asking, notYet, leftOpen }

enum StopReason: Codable { case user, usageLimit(resetsAt: Date?), signedOut, crashed(String), timeout }
```

The whole `Spec` is saved to `specs/.mel/state.json` on every change (debounced, atomic). It's small; no database. The library is an array of folder bookmarks in `UserDefaults`.

## 3. Key flows

### Pipeline

A pure reducer in `Spec/`:

```
discovery ──(all covered | Draft Now)──▶ drafting(product)
drafting(d) ──finished──▶ review(d)
drafting(d) ──error | Stop──▶ stopped(d, reason) ──Resume──▶ drafting(d)   (continues from partial)
                                                 └─Finish myself──▶ review(d)
review(d) ──Approve──▶ drafting(next d) | done
```

### Drafting

1. Build prompt: stage instructions + idea + answers + approved earlier files.
2. Run `claude -p` with stream output and write tools disabled.
3. Append text chunks to an in-memory buffer; write the file at most every 500 ms (atomic). The live preview observes the buffer, throttled to ~10 updates/s.
4. Progress = count of `##` sections in the buffer vs. the expected count (DESIGN.md has 6; for REQUIREMENTS/TASKS the prompt asks the agent to start with a one-line plan, e.g. `5 stories`, stripped from the file). The step list and "section 3 of 6" come from this.
5. On finish: trim, ensure final newline, write, → review.

### Stop and resume

- **Stop**: `SIGINT`, then `SIGTERM` after 3 s. The partial file is already on disk.
- **Resume after stop**: new run with `--resume <sessionID>` and "continue from the first incomplete section"; Mel truncates the file to the last complete `##` section, then appends.
- **Usage limit**: notification at `resetsAt` if known; the user taps Resume. No automatic scheduled runs.

### Review

- Preview = parsed Markdown rendered with SwiftUI. Edit = `TextEditor` on the raw text (switch to `NSTextView` only if large files feel slow).
- In-app edits save on change (debounced, atomic).
- External edits: watch the file (`DispatchSource`). If the in-app editor has no unsaved changes → reload. If it does → ask "Keep Mine / Use File". No merge algorithm.
- Assumptions and open questions are plain callouts in the file; Confirm / Change / Answer Now are small text edits Mel applies to the file.
- The activity log during drafting lives in memory only (not persisted).
- Approve: status → approved. Editing an approved file sets it back to review; nothing else cascades.

### Detection

Read the login-shell `PATH` once per scan (`$SHELL -l -c 'printf %s "$PATH"'`, 5 s timeout), add the extra search paths, find `claude`, run `claude --version`, check auth. Details in [AGENT-INTEGRATION.md](AGENT-INTEGRATION.md).

## 4. Interfaces

```swift
protocol AgentAdapter: Sendable {
    func detect(searchPaths: [String]) async -> AgentStatus     // ready / notSignedIn / missing
    func loginCommand(_ exe: URL) -> String
    func arguments(for request: AgentRequest) -> [String]
    func parse(line: Substring) -> AgentEvent?                   // one NDJSON line
    func stopReason(exitCode: Int32, lastError: String?) -> StopReason
}

enum AgentEvent { case session(String), text(String), step(String), json(Data), done, failed(StopReason) }

actor AgentRunner {
    func run(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, Error>
    func stop()
}
```

System integration:

| Action | How |
|---|---|
| Open Terminal with a command | Write a temporary `.command` script and `NSWorkspace.open` it. No Apple Events entitlement or permission prompt |
| Show in Finder | `NSWorkspace.shared.activateFileViewerSelecting` |
| Copy | `NSPasteboard.general` |
| Git commit | `/usr/bin/git` via `Process`; checkbox disabled if git is unavailable |
| Notifications | `UNUserNotificationCenter` |

## 5. Performance

- Never block the main actor: process I/O, file writes and Markdown parsing run off it.
- Read stdout in chunks and split lines in the runner; don't decode JSON on the main actor.
- Throttle UI updates from the stream (~10/s) and debounce disk writes (500 ms).
- Parse Markdown once per change into blocks and render blocks lazily (`LazyVStack`).
- Launch fast: no work at launch except restoring the library; detection runs in the background.

## 6. Security and privacy

- Mel itself makes no network calls and has no telemetry.
- Claude Code runs with write and shell tools disabled, working directory = the project folder.
- Prompts and history stay in the spec folder.
- `.mel/` is added to `.gitignore` when committing (setting).
- A user-chosen executable must exist, be executable and answer `--version`.

## 7. Testing

- Unit: pipeline reducer, Markdown parser (stories, criteria, callouts, tasks).
- Agent: parse recorded NDJSON fixtures (success, usage limit, signed out, crash); runner tests with a fake `claude` shell script (stop, timeout).
- End to end with the fake script: idea → 4 files → done; stop and resume.
- `#Preview` for every screen state using fixtures.
- Before each release: real Claude Code run, installed from the notarized DMG on a clean account.
