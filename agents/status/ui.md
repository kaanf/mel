# ui status

Wave: 0
Updated: 2026-11-23

## Done
- Wave 0 components in `Mel/Views/Components/`: StatusBadge, StageStepper, RadioRow, CalloutView, KeyHint, ProgressStrip. Type-check clean with `swiftc -typecheck -swift-version 6 -target arm64-apple-macos26.0` (also with `-default-isolation MainActor`).

## In progress
- (nothing)

## Next
- Wait for orchestrator to start Wave 1. Then rebase on origin/main and add `#Preview`s for every Wave 0 component once the Xcode project exists, then 0.2 MelApp and 3.1–3.10 screens.

## Notes
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
