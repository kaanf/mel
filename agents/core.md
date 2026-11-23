# Agent: core

You build Mel's foundation and its brain: the Xcode project, the data model, the pipeline, Markdown parsing, storage, and the `AppState` / `SpecSession` objects the UI binds to.

Read first: `CLAUDE.md`, `agents/README.md`, `agents/CONTRACTS.md`, `docs/DESIGN.md`, `docs/SPEC-FORMAT.md`, `docs/REQUIREMENTS.md`, `docs/AGENT-INTEGRATION.md` (Stage protocols, Prompts).

## You own

- `Mel.xcodeproj/` (only you change project settings)
- `Mel/Spec/`, `Mel/Storage/`, `Mel/Session/`
- `MelTests/Spec/`, `MelTests/Storage/`, `MelTests/Session/`
- `agents/status/core.md`

In Wave 0 only, you also create the contract stubs in `Mel/Agent/`, `Mel/System/` and a placeholder `Mel/App/MelApp.swift`. After G0 those belong to platform and ui; don't touch them again.

## Wave 0 · Foundation

1. **0.1 Xcode project.** Create `Mel.xcodeproj` by writing `project.pbxproj` directly (objectVersion 77):
   - App target `Mel` (macOS 26.0, bundle id `com.kaanf.mel`, Swift 6, default actor isolation MainActor, approachable concurrency, Hardened Runtime, no sandbox, generated Info.plist), test target `MelTests` (Swift Testing, host app `Mel`), shared scheme `Mel` that builds and tests both.
   - Both targets use `PBXFileSystemSynchronizedRootGroup` for `Mel/` and `MelTests/`, so files are picked up without editing the project.
   - Folder skeleton from CONTRACTS.md › Project conventions (keep empty folders with a `.gitkeep`).
2. **Contract stubs.** Every type and signature in CONTRACTS.md, in the files named there. Bodies: trivial or `fatalError("stub")`; `preview(…)` factories must work (previews will use them).
3. `MelApp.swift` placeholder: one `WindowGroup` with `Text("Mel")`.
4. One passing test, e.g. `DocKind.fileName`.

Done when: `xcodebuild -project Mel.xcodeproj -scheme Mel -destination 'platform=macOS' -derivedDataPath .build/DerivedData test -quiet` passes. Commit, push, update status, stop. You are merged first; the others wait for you.

## Wave 1 · Parts

- **2.1** `Spec/Models.swift` real implementations; `Spec/Reducer.swift`: the pipeline from DESIGN.md › Pipeline as a pure function, with unit tests for every transition (including: Approve blocked while assumptions remain, editing an approved file → review).
- **2.2** `Spec/MarkdownParser.swift`: line-based parser for SPEC-FORMAT.md (headings, paragraphs, lists, criteria, tasks + `Covers:`, `[!ASSUMPTION]` callouts, fenced code) and `summary`. Tests with real-looking files (use `docs/*.md` in this repo as samples).
- **2.3** `Storage/SpecStore.swift`: create `<parent>/<slug>/specs`, atomic writes, `.mel/state.json` (whole `Spec`, debounced), existing-file check.
- **2.4** `Storage/FileWatcher.swift`: reload on external change; signal a conflict when the editor has unsaved text (UI shows Keep Mine / Use File).
- **2.5** `Storage/Library.swift`: library as folder bookmarks in `UserDefaults`, missing-folder detection.
- **4.1** `Spec/Prompts/*.md` (discovery, product, requirements, design, tasks, continue) + a builder with `{{placeholder}}` string replacement. Follow AGENT-INTEGRATION.md: no question limit, completeness rule, assumptions.

Done when: all of the above have tests, everything is green, status updated.

## Wave 2 · Wiring

Make `AppState` and `SpecSession` real, depending only on `AgentRunning` (inject; use a fake in tests):

- **4.2** discovery loop: JSON turns, coverage updates, "You decide" → agent decides + assumption, Draft Now, manual Retry on unreadable output.
- **4.3** drafting: stream into `liveText`, debounced atomic writes (500 ms), UI updates throttled (~10/s), plan line stripped, progress from `##` count.
- **4.4** review actions: `save`, confirm/change assumption, approve (blocked while assumptions remain) and start the next file.
- **4.5** recovery: stop, resume with `--resume` (truncate to last complete `##` section), finish by hand; usage-limit reset → `Notifier.post(at:)`.
- **4.8** one run at a time via `AppState.runningSpecID`.

Done when: a test drives idea → 4 approved files with a fake `AgentRunning`, including a stop and resume.

## Wave 3 · Ship

- **5.1** End-to-end tests with platform's `MelTests/Fixtures/fake-claude.sh` through the real `AgentRunner`.

## Don't

- Don't edit `Mel/Agent/`, `Mel/System/`, `Mel/App/`, `Mel/Views/` after Wave 0.
- Don't add dependencies or extra targets.
- Don't import SwiftUI in `Spec/` or `Storage/`; `Spec/` stays pure (no I/O).
