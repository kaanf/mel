# core status

Wave: 7 merged (d62dad7), standing by
Updated: 2026-11-23

## Done
- W6 reducer (`Pipeline.swift`): sizes, approve with open items, revise queue (`Spec.queue`), analyze stage/result, edited → later files stale, undo / keepAsIs / refine. 24 tests.
- W6 parser: open questions, priority/source/MVP line, Q criteria, flow Covers, ordered items, tables, wrapped list items; DocSummary v2 counts.
- W6 MelSpec formats: Intake/Analyze/Impact/ProjectContext decode, DECISIONS.md write/parse, SpecTask parse + per-task prompt, modules, BugReport.ideaText, AgentsFile.merge, step markers + trailer, fixed B3 steps. Decoders also run over platform's real v2 fixtures (`MelAgentTests/V2DecodeTests`).
- W6 storage: SpecStore scan/snapshots/decisions/attachments/task prompts; ProjectStore context/Add Rule/isEmpty/createProject.
- W6 prompts: project, intake, product, requirements, experience, architecture, tasks, spec, revise, analyze, impact, continue; rules.md / rules-no-gaps.md. SPEC-FORMAT.md rewritten from V2.md §6.
- W6 fix: `URL.normalizedFolder` (no disk access) for project URLs.
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

- W7 (v2 session wiring): `SpecSession` rewritten for v2 (one-shot intake; draft/revise through `advance()`; step markers and round-2 trailer; approve saves a snapshot; analyze/fix/handOff; C1 impact after a debounced save of an approved file, `saveDecision`, undo, keepAsIs, refine; attachments; task prompts; AGENTS.md; async `finish` with git off the main actor; decisions recorded automatically). `AppState` rewritten (project library, scan, `setUpProject`, `findRepositories`, `createSpec(…, parent:)`, `specFolder(name:size:project:parent:)`, `isAgentBusy`). `AgentRequest.allowsTools` (false for analyze/impact). `.mel/project/context.json` stores `read`/`sources`.
- W7 tests: `SpecSessionTests` (16, FakeRunner), `EndToEndTests` (Quick fix, Feature with the real project-context recording + attachment + Draft Now + fenced analyze + hand off + task prompts + AGENTS.md, Product with Stop/resume, round 2, analyze fix, impact and refine; one run at a time; unknown resume), `AppStateTests` (findRepositories, createSpec without project). v1 e2e fixtures removed; `e2e/README.md` describes `v2/`. Full suite green 3 runs (184 tests).
- Found by the W7 tests: (1) DECISIONS.md was loaded in an init Task that could overwrite decisions recorded right after `start()`; now read synchronously in init, snapshots merged. (2) `MarkdownParser` dropped `Covers:` when it followed `Priority:` (the v2 task format) and dropped `Q1` IDs, so B5 showed covered criteria as uncovered.

## In progress
- (nothing)

## Next
- Standing by. When the orchestrator says ui's B1 is on main: remove v1 `specFolder(name:parent:)` and `createSpec(name:idea:parentFolder:)` once ui's NewSpecSheet stops using them.

## Notes
- `SpecSession` holds `AppState` weakly; tests keep the AppState alive. `AppState.init` takes `defaults:` (tests pass a throwaway suite; previews use suite "preview" and never save the library).
- `changeAnswer` only records the new answer; it does not drop later questions. The next turn sees it.
- A run refused because another spec is running (or Claude Code isn't ready) sets `lastError`; during drafting the file goes to `stopped(kind, .user)` so Continue Drafting works.
- `DocKind` is now `CodingKeyRepresentable`, so `docs` encodes as a JSON object in state.json, e.g. `"product" : "locked"`.
- `Spec.init` has defaults for a new spec (stage `.discovery`, the size's files locked). `DocKind.next`/`allLocked` are gone: use `size.file(after:)` / `size.allLocked`.
- v1 session still runs until Wave 7: v1 `createSpec(name:idea:parentFolder:)` makes Product-size specs and drafts with the v2 file prompts (no project context, no attachments); discovery.md (phase `experience`) still drives Discovery; a finished spec stops at `.analyze` (no analyze run yet). v1 state.json no longer decodes (v1 specs dropped).
- `summary(_:kind:)` leaves `uncoveredCriteria` empty because it needs both files. In Wave 2, SpecSession fills it for `.tasks` from `uncoveredCriteria(requirements:tasks:)`.
- Placeholders. discovery: name, idea, answers, coverage. product: name, idea, answers, decide. requirements and design: those plus approved. tasks: name, idea, decide, approved. continue: file, partial. Session formats answers, coverage, decide and approved as Markdown text in Wave 2.
- FileWatcher's `onChange` runs on a background queue, so Session must hop to the main actor. Call `noteWritten` before every write Mel makes; each call adds a pending text, which is cleared when that text (or a newer own write) shows up on disk.
- `Library` isn't Sendable (UserDefaults); use it from AppState on the main actor.
- Wave 2 still needs pure helpers in MelSpec: plan-line strip, truncate to the last complete `##`, assumption confirm/change text edits, and discovery JSON decoding.

## Blocked
- (nothing)

## Requests to orchestrator
- (none) W7 merged; CONTRACTS updated for async finish (d8a31b4).

## Questions for the user
- A4x (first spec, no project): where should Mel create the new project folder? I'm using `~/Developer/<slug>/` if `~/Developer` exists, else `~/<slug>/`. A folder picker would need a UI change.
