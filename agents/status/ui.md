# ui status

Wave: 4 (rebased on core, green; waiting for the toolbar check)
Updated: 2026-11-23

## Done
- Wave 0 components (merged): StatusBadge, StageStepper, RadioRow, CalloutView, KeyHint, ProgressStrip.
- Wave 1, rebased on origin/main (7becaf0), `xcodebuild test` green, no warnings from App/ or Views/:
  - 0.2 `App/MelApp.swift` + `App/MelCommands.swift`: WindowGroup → MainView (NavigationSplitView, inspector per screen), `Window("Welcome", id: "welcome")`, Settings (single Agents pane), commands ⌘N New Spec…, ⌘↩ Approve (Spec menu), ⌥⌘I Show/Hide Inspector. AppState(adapter:makeRunner:) wiring kept as core wrote it.
  - 3.1–3.10 in `Views/`: Welcome, Settings › Agents, Sidebar, New Spec sheet, Discovery (+ inspector), MarkdownBlocksView (LazyVStack, EARS keywords bold), Drafting (running/stopped + live preview inspector), Review (Preview / Edit Markdown, Before you approve, Approve disabled while assumptions remain), Failure sheet, Spec ready sheet. Plus EmptyLibraryView, LockedDocView, AgentRow/AgentStatusBadge.
  - `#Preview`s for every component and screen state, data in `Views/Preview/PreviewData.swift`.

- Wave 2, rebased on origin/main (c5c1487), full `xcodebuild test` green (114 passed), no warnings from App/ or Views/. merged to main (1fad575)
  - Discovery keyboard: digits 1…N pick an option (ignored while the note field has focus), ↩ is Continue. Question card takes focus on appear.
  - Keep Mine / Use File: alert in Review while `session.conflict == kind` → `resolveConflict(keepMine:)`. Review no longer debounces itself; it calls `save` on change and the session debounces the write.
  - Missing rows: "Missing" section in the sidebar for `missingFolders` (title = project folder name), menu + context menu with Locate… (`fileImporter` → `locate(_:at:)`, error alert) and Remove from List (`removeMissing`).
  - Your Idea › Edit…: sheet in Discovery → `updateIdea`, disabled while running.
  - New Spec shows the resulting folder via `specFolder(name:parent:)` (parent path until a name is typed).
  - Handoff: Git toggle hidden when `!canCommit`; Done with commit on a non-repo asks "Create Repository and Commit" first. Both values read once in `.task`.
  - Previews added: Discovery Error, Edit Idea, Sidebar Missing folder. `PreviewData.session(lastError:)`, `PreviewData.appState(missing:)`.
  - Launch: MelApp calls `scanForAgent()` once in the main window's `.task`.
  - Kept core's `.sessionNotFound` in FailureSheet's `.user` case.

- Conflict preview: ReviewView "Changed in another app" (edit mode, `conflict: .requirements`) via `PreviewData.session(conflict:)`. Rebased on d4bc101, full test green (119 passed). merged to main (81ea2b7). Wave 2 done.

- Wave 3 · 5.2 accessibility pass, rebased on a65a608, full test green (119 passed), no warnings from App/ or Views/. merged to main (5a064e8):
  - Reduce Motion: ProgressStrip only runs its phase animator while indeterminate and running (before, it animated forever, even with the pulse off). StatusBadge pulse already respected it.
  - Increase Contrast: selected RadioRow gets a tint border (its fill is `.quinary`).
  - VoiceOver: RadioRow hint is "Shortcut N" (Suggested is already in the label); question card is one container labeled "Question N"; sidebar file rows read as one element (name + status); missing row menu is "Actions for <project>".
  - Audit, no change needed: semantic colors and SF Symbols only, decorative images hidden, headers marked, status never color-only (always text), every sheet has a ↩ default action and Cancel/Esc where cancelling makes sense, menus and context menus are reachable with VoiceOver.

- App icon (5.2): `Mel/Assets.xcassets` (root Contents.json) with the user's `AppIcon.appiconset` copied unchanged from mel-icon-kit. Rebased on aa80cfd, full test green (122 passed), no warnings without the icon build setting. **ready to merge**

- fix(ui) status text in toolbar (3.5): StatusBadge is an HStack (Image + Text, lineLimit 1, tail truncation, image hidden for VoiceOver, combined element) instead of a Label, because toolbars draw Labels icon-only. Checked in the running debug app with fixture specs (launch-argument `-library`): Discovery shows "Needs you · Claude Code is waiting for an answer", Drafting shows "Stopped". Not checked: "Running · …" (needs a live agent run) and truncation in a narrow window (the app quit during that check, no crash report; the user was testing at the same time). Rebased on 25a5d7c, full test green (122). **ready to merge**

- fix(ui) toolbar padding (3.5, 8dddc94): 10 pt horizontal padding around the `.status` toolbar items in Discovery and Drafting (not in StatusBadge itself, which also sits inline). Compiles, test green (122). NOT verified: padding and truncation are unchecked. My debug screenshots turned out to be of the user's app. Open risk: with `.padding` the toolbar may give the status item too little width again (icon only); if so, try `.fixedSize()` before the padding.

## In progress
- ## In progress
- Wave 4 rebased on origin/main 5b9883b (core's phased discovery model), stub dropped. Full test green (130 passed, 0 failed).
  - Open question card (`options` empty): multi-line `TextField(axis: .vertical)`, Continue ↩ → `.text(trimmed)` (disabled when empty), Skip → `.agentDecides`, field focused on appear, digit keys ignored.
  - Answered open questions: a row opens a popover to edit the text; Save with empty text → `.agentDecides`; unchanged answer sends nothing. Shown as the text, or "Skipped · the agent decides" (replaces core's one-line `.text` case in answerText).
  - Inspector: one Section per phase in file order (only phases with items), header "Phase · n of m", footer on the last.
  - Previews: "Open Question" (answered text + skipped open question in the list, phased inspector), "Inspector". Fixtures: `PreviewData.openQuestion`, `discoveryOpen`, coverage with phases.
  - Toolbar padding/truncation (8dddc94) NOT verified yet: waiting for the orchestrator to say /Applications/Mel.app is closed.

## Next
- Verify the toolbar status in the Debug build once the orchestrator says /Applications/Mel.app is closed. If the text drops: `.fixedSize()` before the padding. Then tell the orchestrator "ready to merge".

ecks: System Events can't tell two "Mel" processes apart (`first process whose unix id is …` + `window 1` still hit /Applications/Mel.app on 2026-11-23). Rule (orchestrator): no System Events / GUI scripting at all while /Applications/Mel.app is running, debug pid or not. Screenshots come from the orchestrator/user. Earlier toolbar screenshots after 15:55 were of the user's app, not the debug build.
- While the user runs an install test of /Applications/Mel.app: don't launch the debug app, don't touch com.kaanf.mel defaults, and don't run the full xcodebuild test (MelTests are hosted by Mel.app, same bundle id). Only `cd MelKit && swift test`. Wait for the orchestrator to say the test is over.
- Running the debug app touches the real `com.kaanf.mel` defaults (same bundle id). Pass fixtures as launch arguments (`--args -library '<hex>' -didShowWelcome YES`); `CFFIXED_USER_HOME` does NOT isolate `defaults write`.
- Views import only SwiftUI, MelSpec, UniformTypeIdentifiers (fileImporter). File pickers are `fileImporter`; chosen URLs go to AppState/SpecSession.
- Parsing runs off main via `parseDocument(_:kind:)` (@concurrent) in `.task(id: text)`; Review saves edits after 500 ms debounce via `session.save`.
- MarkdownParser is still a stub, so ReviewView/LivePreview previews render empty bodies until core 2.2; `ReviewDocument` and `MarkdownBlocksView` previews use block fixtures and show the real look.
- Previews compile with the build; I did not open them in Xcode's canvas, so visual rendering is unchecked.
- Approve is a FocusedValue (`\.approve`, plain FocusedValueKey; `@Entry` warns for closures). A ternary producing `approve : nil` crashed the compiler; use if/guard.
- Spec ready sheet opens when stage changes to `.done` while Review is shown; "Start Building…" in the Review toolbar reopens it.
- @AppStorage key: `didShowWelcome` (ui). Settings is a single Agents pane (no TabView, no scan-on-launch toggle).
- Commit-to-Git checkbox defaults to off.

## Blocked
- (nothing)

## Requests to orchestrator
- core is setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on the Mel target (separate commit); until then the icon set is in the catalog but not used.
- (none; Wave 1 requests are in CONTRACTS 884c099. "Story 3 of 5" is cut, step list stays.)
- core: ui calls `scanForAgent()` at launch, so AppState.init should not scan too.

## Questions for the user
- (none)
