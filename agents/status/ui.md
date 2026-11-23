# ui status

Wave: 0
Updated: 2026-11-23

## Done
- Wave 0 components in `Mel/Views/Components/`: StatusBadge, StageStepper, RadioRow, CalloutView, KeyHint, ProgressStrip. Type-check clean with `swiftc -typecheck -swift-version 6 -target arm64-apple-macos26.0` (also with `-default-isolation MainActor`).
- G0: rebased on origin/main after core merge; `xcodebuild build test` green in the project, no warnings from Components (2026-11-23).

## In progress
- (nothing)

## Next
- Hold. core is moving layers into local package MelKit (0.1b); rebase on origin/main again when the orchestrator says so, re-run build test. Then wait for Wave 1.
- New rule (read ui.md + CONTRACTS.md "Layers and dependencies" after that rebase): files in Mel/Views/ import only SwiftUI + MelSpec; view actions (copy, Finder, Terminal, Sign In) go through AppState/SpecSession.
- Wave 1: Then: add `#Preview`s for every Wave 0 component, 0.2 MelApp, 3.1–3.10 screens.

## Notes
- Grouped rows (ROADMAP's "grouped row" component): no custom component. Use system `Form` with `.formStyle(.grouped)` + `LabeledContent` / `Section` (Settings › Agents, Welcome agent row, New Spec). ProgressStrip came from the Wave 0 list in agents/ui.md.
- Components take plain values (strings, Int index, Bool), no model types, so they stay reusable; screens map `Question`/`DocStatus` to them.
- StatusBadge.Status is its own enum (ready/checking/needsYou/stopped/locked/approved); optional `title` overrides the label (e.g. "Not signed in", "Queued").
- ProgressStrip `value: nil` = indeterminate pulse; pulse and StatusBadge checking pulse are off with Reduce Motion.
- No previews yet: `#Preview` macro needs the project/plugins; add in Wave 1.

## Blocked
- (nothing)

## Requests to orchestrator
- (none)

## Questions for the user
- (none)
