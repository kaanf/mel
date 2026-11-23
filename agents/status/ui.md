# ui status

Wave: 1
Updated: 2026-11-23

## Done
- Wave 0 components (merged): StatusBadge, StageStepper, RadioRow, CalloutView, KeyHint, ProgressStrip.
- Wave 1, rebased on origin/main (7becaf0), `xcodebuild test` green, no warnings from App/ or Views/:
  - 0.2 `App/MelApp.swift` + `App/MelCommands.swift`: WindowGroup → MainView (NavigationSplitView, inspector per screen), `Window("Welcome", id: "welcome")`, Settings (General / Agents / Specs / Advanced), commands ⌘N New Spec…, ⌘↩ Approve (Spec menu), ⌥⌘I Show/Hide Inspector. AppState(adapter:makeRunner:) wiring kept as core wrote it.
  - 3.1–3.10 in `Views/`: Welcome, Settings › Agents, Sidebar, New Spec sheet, Discovery (+ inspector), MarkdownBlocksView (LazyVStack, EARS keywords bold), Drafting (running/stopped + live preview inspector), Review (Preview / Edit Markdown, Before you approve, Approve disabled while assumptions remain), Failure sheet, Spec ready sheet. Plus EmptyLibraryView, LockedDocView, AgentRow/AgentStatusBadge.
  - `#Preview`s for every component and screen state, data in `Views/Preview/PreviewData.swift`.

## In progress
- (nothing)

## Next
- Wait for Wave 2 (wiring, keyboard 1–4/↩ in Discovery, Keep Mine / Use File, missing-folder rows).

## Notes
- Views import only SwiftUI, MelSpec, UniformTypeIdentifiers (fileImporter). File pickers are `fileImporter`; chosen URLs go to AppState/SpecSession.
- Parsing runs off main via `parseDocument(_:kind:)` (@concurrent) in `.task(id: text)`; Review saves edits after 500 ms debounce via `session.save`.
- MarkdownParser is still a stub, so ReviewView/LivePreview previews render empty bodies until core 2.2; `ReviewDocument` and `MarkdownBlocksView` previews use block fixtures and show the real look.
- Previews compile with the build; I did not open them in Xcode's canvas, so visual rendering is unchecked.
- Approve is a FocusedValue (`\.approve`, plain FocusedValueKey; `@Entry` warns for closures). A ternary producing `approve : nil` crashed the compiler; use if/guard.
- Spec ready sheet opens when stage changes to `.done` while Review is shown; "Start Building…" in the Review toolbar reopens it.
- @AppStorage keys: `didShowWelcome` (ui), `scanOnLaunch` (Settings toggle, default true; core should read it at launch).
- Commit-to-Git checkbox defaults to off.

## Blocked
- (nothing)

## Requests to orchestrator
- core: `SpecSession.preview(... lastError:)` so the Discovery error state (Try Again) gets a preview.
- core: `SpecSession.updateIdea(_:)` for "Your Idea › Edit…" (button left out until it exists).
- core: a way to show the resulting spec folder in New Spec (e.g. `AppState.specFolder(name:parent:) -> URL`); the sheet shows only the parent path now.
- core, confirm semantics I wired: New Spec calls `session.start()` after `createSpec`; Drafting "Review What's Written" and Failure "Open File" call `finishByHand()`; Failure "Resume Later" (usage limit) calls `resume()` and expects core to wait for the reset.
- core: agent "Choose File…/Change…" appends the executable's folder to `extraSearchPaths` and calls `scanForAgent()`; extraSearchPaths needs persisting.
- core (nice to have): total count for "Writing story 3 of 5"; Drafting step list is built from activity lines for now.

## Questions for the user
- Settings General / Specs / Advanced are placeholders ("No Settings Yet"). Build the proposal in docs/UI.md › Settings, or leave them out of the MVP?
