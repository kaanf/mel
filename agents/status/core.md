# core status

Wave: 2
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

## In progress
- (nothing)

## Next
- 5.1 in Wave 3 (end-to-end with fake-claude.sh).
- Once platform adds `AgentRequest.systemPrompt`, decide with the orchestrator whether to move the stage contract out of the prompt files. Today everything goes on stdin.

## Notes
- `SpecSession` holds `AppState` weakly; tests keep the AppState alive. `AppState.init` takes `defaults:` (tests pass a throwaway suite; previews use suite "preview" and never save the library).
- `changeAnswer` only records the new answer; it does not drop later questions. The next turn sees it.
- A run refused because another spec is running (or Claude Code isn't ready) sets `lastError`; during drafting the file goes to `stopped(kind, .user)` so Continue Drafting works.
- `DocKind` is now `CodingKeyRepresentable`, so `docs` encodes as a JSON object in state.json, e.g. `"product" : "locked"`.
- `Spec.init` has defaults for a new spec (stage `.discovery`, all docs locked, empty questions and coverage). There is also `DocKind.next` and `DocKind.allLocked`.
- `summary(_:kind:)` leaves `uncoveredCriteria` empty because it needs both files. In Wave 2, SpecSession fills it for `.tasks` from `uncoveredCriteria(requirements:tasks:)`.
- Placeholders. discovery: name, idea, answers, coverage. product: name, idea, answers, decide. requirements and design: those plus approved. tasks: name, idea, decide, approved. continue: file, partial. Session formats answers, coverage, decide and approved as Markdown text in Wave 2.
- FileWatcher's `onChange` runs on a background queue, so Session must hop to the main actor. Call `noteWritten` before every write Mel makes; each call adds a pending text, which is cleared when that text (or a newer own write) shows up on disk.
- `Library` isn't Sendable (UserDefaults); use it from AppState on the main actor.
- Wave 2 still needs pure helpers in MelSpec: plan-line strip, truncate to the last complete `##`, assumption confirm/change text edits, and discovery JSON decoding.

## Blocked
- (nothing)

## Requests to orchestrator
- Wave 2 ready to merge: 2567564 (+ status commit).
- Not done, needs a decision: REQ 5.8 "notify when a file finishes if Mel isn't frontmost". Session can't check frontmost without AppKit. Either Notifier gets an `isAppActive` check, or MelApp tells AppState. Also: `Notifier.post` is still a platform stub (fatalError); resume after a usage limit calls it.
- Stubs ready ed94bba (merged?). Note: adding `StopReason.sessionNotFound` broke the exhaustive switch in ui's `Mel/Views/Failure/FailureSheet.swift`; that commit adds `.sessionNotFound` to the `.user` case (one line) so main compiles. Tell ui.

## Questions for the user
- (none)
