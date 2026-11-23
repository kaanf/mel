# core status

Wave: 0
Updated: 2026-11-23

## Done
- 0.1 Xcode project (objectVersion 77, synchronized folders, shared scheme `Mel`), folder skeleton, contract stubs for every CONTRACTS.md type, `MelApp` placeholder, `DocKind.fileName` test. `xcodebuild … build test` green, no warnings.

## In progress
- (nothing)

## Next
- Wait for the orchestrator to merge G0 and open Wave 1 (2.1 Models + Reducer first).

## Notes
- Empty folders hold a `.gitkeep`. Synchronized folders would copy them as resources ("Multiple commands produce …/.gitkeep"), so `project.pbxproj` has a membership exception set per target listing each `.gitkeep`. Stale entries after a `.gitkeep` is deleted are harmless; a **new** `.gitkeep` in a new folder needs an entry (ask core).
- Default actor isolation is MainActor. Value types in Spec/ and Agent/AgentTypes, the two protocols, `ClaudeCode`, `ShellPath`, `Git` and `MarkdownParser` are marked `nonisolated` (+ `Sendable`) so parsing and process work can run off the main actor and `AgentEvent`/`StopReason` cross actors. Signatures are unchanged otherwise.
- `MarkdownParser` stub returns empty results (not fatalError) so `SpecSession.summary` works in previews. `AppState.session(for:)` returns a preview session for now.
- Code signing: ad-hoc (`CODE_SIGN_IDENTITY = "-"`), no team set. Notarization setup is for later.

## Blocked
- (nothing)

## Requests to orchestrator
- CONTRACTS: note the `nonisolated`/`Sendable` markings above so platform/ui keep them.

## Questions for the user
- (none)
