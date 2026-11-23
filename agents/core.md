# Agent: core

You build Mel's foundation and its brain: the Xcode project, the data model, the pipeline, Markdown parsing, storage, and the `AppState` / `SpecSession` objects the UI binds to.

Read first: `CLAUDE.md`, `agents/README.md`, `agents/CONTRACTS.md`, `docs/DESIGN.md`, `docs/SPEC-FORMAT.md`, `docs/REQUIREMENTS.md`, `docs/AGENT-INTEGRATION.md` (Stage protocols, Prompts).

## You own

- `Mel.xcodeproj/` and `MelKit/Package.swift` (only you change project or package settings)
- `MelKit/Sources/MelSpec/`, `MelKit/Sources/MelStorage/`, `Mel/Session/`
- `MelKit/Tests/MelSpecTests/`, `MelKit/Tests/MelStorageTests/`, `MelTests/Session/`
- `agents/status/core.md`

In Wave 0 only, you also create the contract stubs in `MelKit/Sources/MelAgent/`, `MelKit/Sources/MelSystem/` and a placeholder `Mel/App/MelApp.swift`. After G0 those belong to platform and ui; don't touch them again.

## Wave 0 · Foundation

1. **0.1 Xcode project.** Create `Mel.xcodeproj` by writing `project.pbxproj` directly (objectVersion 77):
   - App target `Mel` (macOS 26.0, bundle id `com.kaanf.mel`, Swift 6, default actor isolation MainActor, approachable concurrency, Hardened Runtime, no sandbox, generated Info.plist), test target `MelTests` (Swift Testing, host app `Mel`), shared scheme `Mel` that builds and tests both.
   - Both targets use `PBXFileSystemSynchronizedRootGroup` for `Mel/` and `MelTests/`, so files are picked up without editing the project.
   - Folder skeleton from CONTRACTS.md › Project conventions (keep empty folders with a `.gitkeep`).
2. **Contract stubs.** Every type and signature in CONTRACTS.md, in the files named there. Bodies: trivial or `fatalError("stub")`; `preview(…)` factories must work (previews will use them).
3. `MelApp.swift` placeholder: one `WindowGroup` with `Text("Mel")`.
4. One passing test, e.g. `DocKind.fileName`.

Done when: `xcodebuild -project Mel.xcodeproj -scheme Mel -destination 'platform=macOS' -derivedDataPath .build/DerivedData test -quiet` passes. Commit, push, update status, stop. You are merged first; the others wait for you.

## Wave 0b · Modules (0.1b)

The user wants the layers enforced by the compiler. Do this on top of `origin/main` (core + platform merged):

1. Create `MelKit/Package.swift` (`swift-tools-version: 6.2`, `.macOS(.v26)`, Swift 6 language mode, package default isolation, no dependencies) with library targets `MelSpec`, `MelStorage` (→ MelSpec), `MelAgent` (→ MelSpec), `MelSystem` (no deps) and test targets `MelSpecTests`, `MelStorageTests`, `MelAgentTests` (resources: `Fixtures/`), `MelSystemTests`.
2. `git mv` the files: `Mel/Spec` → `MelKit/Sources/MelSpec`, `Mel/Storage` → `MelStorage`, `Mel/Agent` → `MelAgent` (keep platform's ShellPath), `Mel/System` → `MelSystem`, tests likewise. Prompts become a `MelSpec` resource (`Bundle.module`).
3. Apply CONTRACTS.md › Layers and dependencies: `AgentStatus` moves into `MelSpec/Models.swift`; drop the `nonisolated` markers inside MelKit (package default); add `public` + explicit `public init` only where another module uses the type; add `AppState.init(adapter:makeRunner:)` and the new Session action stubs; `MelApp` becomes the composition root.
4. Project: add `MelKit` as a local package, link the four libraries to `Mel`, turn on `MemberImportVisibility` for the app target, add every MelKit test target to the `Mel` scheme so the one `xcodebuild … test` command runs them all. Remove `.gitkeep` files and their pbxproj exceptions.
5. Run `xcodebuild … test` (green, no warnings), push, update status, stop. ui rebases after your merge.

## Wave 1 · Parts

- **2.1** `MelSpec/Models.swift` real implementations; `MelSpec/Reducer.swift`: the pipeline from DESIGN.md › Pipeline as a pure function, with unit tests for every transition (including: Approve blocked while assumptions remain, editing an approved file → review).
- **2.2** `MelSpec/MarkdownParser.swift`: line-based parser for SPEC-FORMAT.md (headings, paragraphs, lists, criteria, tasks + `Covers:`, `[!ASSUMPTION]` callouts, fenced code) and `summary`. Tests with real-looking files (use `docs/*.md` in this repo as samples).
- **2.3** `MelStorage/SpecStore.swift`: create `<parent>/<slug>/specs`, atomic writes, `.mel/state.json` (whole `Spec`, debounced), existing-file check.
- **2.4** `MelStorage/FileWatcher.swift`: reload on external change; signal a conflict when the editor has unsaved text (UI shows Keep Mine / Use File).
- **2.5** `MelStorage/Library.swift`: library as folder bookmarks in `UserDefaults`, missing-folder detection.
- **4.1** `MelSpec/Prompts/*.md` (discovery, product, requirements, design, tasks, continue) + a builder with `{{placeholder}}` string replacement. Follow AGENT-INTEGRATION.md: no question limit, completeness rule, assumptions.

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

- **5.1** End-to-end tests with platform's `MelKit/Tests/MelAgentTests/Fixtures/fake-claude.sh` through the real `AgentRunner`.

## Don't

- Don't edit `MelKit/Sources/MelAgent/`, `MelKit/Sources/MelSystem/`, `Mel/App/`, `Mel/Views/` after Wave 0.
- Don't add dependencies or extra targets.
- Don't import SwiftUI in `MelSpec/` or `MelStorage/`; `MelSpec/` stays pure (no I/O).
