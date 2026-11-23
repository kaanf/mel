# core status

Wave: 0b
Updated: 2026-11-23

## Done
- 0.1 Xcode project, contract stubs, MelApp placeholder (commit 0ecb41d, merged).
- 0.1b Layers moved into the local package `MelKit` (MelSpec, MelStorage→MelSpec, MelAgent→MelSpec, MelSystem). `AgentStatus` is now in MelSpec. Cross-module API is public with explicit inits. Added `AppState.init(adapter:makeRunner:)`, `signIn`/`copy`, the SpecSession handoff stubs, and `MelApp` as the composition root. `.gitkeep` files and their pbxproj exceptions are gone. The `Mel` scheme runs MelTests plus all four MelKit test targets. `xcodebuild … test` is green with no warnings, and ui's Components (rebased in) build unchanged.

## In progress
- (nothing)

## Next
- Wait for the orchestrator to merge 0.1b and open Wave 1 (2.1 Models + Reducer first).

## Notes
- MemberImportVisibility is on for both app targets (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`).
- SwiftPM needs at least one source file per target, so there are placeholders: `MelStorage/SpecStore.swift` (`enum SpecStore {}`, replaced in 2.3), an empty `MelStorageTests/SpecStoreTests.swift` and an empty `MelSystemTests/SystemTests.swift`. `.copy("Fixtures")` fails if the folder is empty, so `MelAgentTests/Fixtures/README.md` keeps it non-empty.
- Prompts are **not** yet declared as a MelSpec resource, because `Prompts/` has no files yet. Add `resources: [.process("Prompts")]` to MelSpec in Package.swift together with the first prompt in 4.1.
- I added two small `ShellPath` tests in MelAgentTests to give that target real tests. They belong to platform now.
- `AppState.preview` uses a private inert adapter and runner (in AppState.swift).
- Code signing is ad hoc (`CODE_SIGN_IDENTITY = "-"`) with no team set.

## Blocked
- (nothing)

## Requests to orchestrator
- (none)

## Questions for the user
- (none)
