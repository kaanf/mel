# ui status

Wave 6 step 2 in progress: A1, A1x, A2, A3 done; B1 New Spec started (not built yet)
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
- Wave 4 merged to main (ad7c055), full test green (130): open question card (multi-line field, Continue ↩ → `.text`, Skip → `.agentDecides`, digits only for option questions), answered open questions edited in a popover (empty = Skip, shown as "Skipped · the agent decides"), inspector coverage grouped by phase with "n of m", previews "Open Question" and "Inspector".

## In progress
- Wave 5 merged to main (4e37bc9), full test green (131).
- v0.2.1 follow-ups (user-approved) merged to main (e6a5480), full test green (131):
  - feat(ui) short toolbar status: `ToolbarStatus(status:title:detail:compact:)` in StatusBadge.swift. Discovery and Drafting measure their width (content + inspector, `onGeometryChange` after `.inspector`) and pass `compact` below `ToolbarStatus.fullTextWidth` (660). Full and compact are separate `ToolbarItem`s (if/else) because NSToolbar never widens an item whose content grows; ViewThatFits does nothing in a toolbar (AppKit overflows by ideal width). Checked in the Debug app: full text + Draft Now + Inspector at 900 pt (inspector hidden) and 915 pt (shown); "Needs you" with all buttons at 860/760/655 pt; growing back works. A very long spec name in the subtitle can still push items into overflow.
  - fix(ui) sidebar arrows: the question card took focus on every appear, so after arrowing up to Discovery the next arrow went to the card. Now only a question that arrives while Discovery is open takes focus (`openedOn` in DiscoveryView). Checked with keys posted to the debug PID: REQUIREMENTS ↑ PRODUCT ↑ Discovery ↓ PRODUCT ↓ REQUIREMENTS ↑ ↑ Discovery ↓ PRODUCT. Trade-off: opening Discovery from the sidebar no longer puts focus in the card; Tab or a click does. Not unit-testable (focus); no new test.

- feat(ui) honeycomb app icon (v0.2.1) merged to main; shipped in v0.2.1 (build 264).
  - AppIcon.appiconset PNGs rendered from the SVGs in `docs/design/v2/Mel-Logo.dc.html` (scratchpad Swift script: NSImage loads the SVG, draws into an sRGB CGContext; raw pixels check out at Honey #D97F00, Core #2A2A2E). Contents.json unchanged (already lists all 10 slots).
  - 128 pt and up: the 1024 master (sheen, 0.08 hairline). 32@1x and 32@2x use the file's own 32/64 px variants (no sheen; hairline 0.1 at 32 px, 0.08 at 64 px). 16@1x/@2x: small mark (0.14 hairline).
  - Full-bleed like the design (squircle fills the 100 grid, no macOS margin); macOS 26 shows it at the same size as the other Dock icons. Checked in the Debug app (com.kaanf.mel.debug) after `lsregister -f` + Dock restart; before that the Dock showed a cached generic icon.

- Wave 6 Theme (orchestrator-approved before core's stubs): `Mel/Views/Theme.swift`, full test green (132).
  - `Theme.Colors` (semantic, sRGB hex), `Theme.Text` (`TextStyle` size/weight/lineHeight/design/tracking, applied with `.textStyle(_:)`; exact line height via macOS 26 `.lineHeight(.exact(points:))`, `ThemeTests` renders single lines and checks the height), `Theme.Space` (named by value, x1…x72), `Theme.Size` (sidebar 232, toolbar 52, control heights, switch, radio), `Theme.Radius` (3…16; pills use `Capsule()`), `Theme.Elevation` (ring 0.5 outset/inset + one drop or inner shadow) applied with `.surface(fill, elevation, in: shape)`, `Theme.LogoShadow`.
  - No values rounded or merged unless identical and used for the same thing (e.g. four separator opacities stay separate).
  - Light mode: `NSRequiresAquaSystemAppearance` in Info.plist. Checked: Debug app renders Aqua while the system is in Dark mode.
  - Left out on purpose: mock chrome (#DFE0E5 page, traffic lights, window shadow, C4 grey dot), the C2 dialog 4-layer shadow (system sheet), logo colors (the logo is an image). Glass tokens (sidebar, toolbar groups) are kept as reference only, since macOS 26 draws that glass itself.
  - Note: the app target defaults to MainActor isolation, so tokens are MainActor (fine for views; test arguments can't use them).

- Wave 6 step 1, rebased on origin/main, full test green (148):
  - Sidebar = variant (b) as drawn on B5–C3 (orchestrator 2026-11-23), rows drawn by hand: inset panel 232 pt (8 pt from the window, #F6F6F8 = the design's 0.86 alpha over white), 28 pt rows, grey 0.08 selection with medium weight, 26 pt file indent, ↑/↓ via onKeyPress, rows are buttons with `.isSelected`, label "name, status".
  - Status scheme. Drawn in (b): Approved green dot, Review and Edited black ring, Locked dashed grey, Out of date #B25000, n issues #C93400, Rerun #B25000. **Not drawn, same scheme (for the user to confirm):** Drafting = purple pulsing dot (from B3), Stopped = #C93400 dot, Queued (during intake) = Locked's dashed dot with "Queued", Analyze Running = purple dot, Passed = green dot, Discovery during intake = black ring (needs you), after = green dot.
  - **Choices for the user:** project row shows the project name + "Ready" / "No context" (C3's drawing) on every screen, not B5–C1's "Project context" label, because the library can hold several projects; the "New Spec" footer (C3, B2–B4) stays on every screen although C1 omits it; B5's sidebar is drawn wider only because its labels lack `min-width: 0` (a mock artifact), we keep 232 pt and truncate like C1.
  - Text: `.lineHeight(.exact)` puts the extra leading below the glyphs, CSS splits it; `textStyle` offsets by a per-size measured height (residual ≤ 0.125 pt vs WebKit for all 35 styles).
  - Locked dot dash pattern matched to WebKit's rendering (two 4.5 pt dashes). Design icons (house, chevron, plus, alert) drawn from their SVG paths.
  - Status pill: `StatusPill(indicator:text:count:progress:maxWidth:)`, max width per screen (360/340/320/300 as drawn).
  - Comparison tooling (scratchpad, not in repo): WKWebView renderer for `.dc.html` with the canvas's dc-runtime.js as support.js; Debug app `-screen <name>` opens a fixture state at 1280 × 800. Mocks place the traffic lights at 30 pt; the system places them by toolbar height (system chrome, left as is).

- Wave 6 step 2 (screens), rebased on origin/main, last full test green (208 tests, at A3):
  - Done and pixel-compared at 1280 × 800: A1 Welcome, A1x No agent, A2 Pick a project, A3 Project context (commits "feat(ui): A1…", "A2…", "A3…").
  - Lane A runs in the main window: `Views/Setup/SetupFlow.swift` (steps welcome → pickProject → projectSetup(Project) → firstSpec), shown by MainView while `!didShowWelcome || state.projects.isEmpty`. The old separate "Welcome" Window scene is gone. Setup screens draw their own title bar via `setupChrome(title:stepLabel:barHeight:labelTrailing:)`: 44 pt with a centered title (A2, A3, A4x), 52 pt with the "Setup" label (A1 trailing 12, A1x trailing 20). The system toolbar is kept but empty, so the traffic lights stay.
  - Shared parts: `DesignButtonStyle` (role, height, leading/trailing, keyHint, text, elevation override), `DesignLinkStyle`, `SegmentedPicker`, `AgentTile`, `SetupAgentRow`, `DesignIcon` (now parses the design's SVG `d` strings via `SVGPathShape`; glyphs house, chevronDown, plus, alert, terminal, check, folder, folderPlus, doc, gear, close, paperclip, popUp), Logo image asset (Assets.xcassets/Logo, the 1024 icon).
  - Contract additions used (all on main): FoundRepository (A2 meta "Kotlin · edited today"), ProjectSetup.branch/fileCount, ProjectContext.read/sources (A3).

## Next
- **Where I stopped (2026-11-23, Mac shutdown):** last commit is "wip(ui): B1 glyphs (temp)". `DesignIcon` was just rewritten to parse SVG path data (builds; previews of the glyphs not yet compared visually; check the paperclip/alert/gear arcs against the mock at 8× zoom). No B1 view written yet.
- **Next concrete step: B1 New Spec** (`docs/design/v2/Native-1-NewSpec.dc.html`), a full-window screen without sidebar (replaces `NewSpecSheet`; Esc cancels back to the library/C3; MainView shows it when `isShowingNewSpec`). States to build and preview: Feature with project (mock default), Feature without context ("No context yet" badge + "Read Repo (about 1 min)" row), Quick fix (What's wrong? + Happens now / Should happen / Where rows, evidence chips with remove, Add Files + Paste Log; Link Issue hidden V2 §2), Product (no project row; "Or start from an example" chips when empty), empty (Start disabled, footer "Describe … to start."). Parts: 52 pt bar with only the gear button (36×32, glass group) at the right → `openSettings`; logo 32 + "New Spec"; size cards (grid min 150, gap 8; files line "SPEC.md" / "REQUIREMENTS · ARCHITECTURE · TASKS" / "+ PRODUCT · EXPERIENCE"); project box (folder 18, Project label, popup menu of `state.projects`, meta path · branch, ctx badge `successBadge*`/`warningBadge*`, Add Project… → A2); name field 30/36 bold (placeholder "Untitled Spec", hint per size); idea box (textarea 6 rows 15/23, label per size); Builds on chips (Feature + context: `context.modules` + "Something new · new module"); "Mel will ask about" chips from `SpecSize.topics` (6 pt ring dot); settings box (Agent row with Ready check 10 + popup "Claude Code", Save to path + "Developer" popup, Let Mel fill small gaps switch 32×18 → `fillGaps`); footer hint ("About 3 questions, then 3 files and a final check.") + Start ⌘↩ (padding 20/12). All copy and styles are in the mock's script (sizes, copy, hints, topicSets).
- **Interim workarounds open (core approved, pushing):** `AppState.specFolder(name:size:project:parent:)`: until on main, take the slug from v1 `state.specFolder(name:parent:)` (lastPathComponent of its parent). `createSpec(…, project:, parent: URL? = nil, …)`: until on main, Product without project has no parent to pass. Switch both to the real API after `git fetch && git rebase origin/main`.
- Then A4x (`Native-E4-FirstSpec.dc.html`, own view from B1's parts: centered "New Spec" 44 pt bar, sizes Product/Feature/Quick fix with "Needs a project · Add One", "Not sure how to start? Try one" examples), then B2–B7, C1–C4 per FLOW.md, each with a `#Preview` per drawn state and a side-by-side compare before "ready to merge".
- Comparison tooling lives in the scratchpad (lost on reboot); rebuild if needed: WKWebView renderer of `.dc.html` with the canvas artifact's `artifact-type/dc-runtime.js` saved as `support.js` next to the mocks (Artifact read of https://claude.ai/artifact/EoySYJYRhntvx3G6u19EFd), Debug app `-screen <name>` (see `Views/Preview/DebugScreen.swift`; delete the debug domain's "NSWindow Frame SwiftUI.WindowGroup…" key first so the window opens at 1280 × 800; `-didShowWelcome NO` for A1/A1x), crop the mock render at (80, 80, 2560 × 1600) px. App captures are Display P3 encoded (#007AFF reads #3478F6), compare positions, not raw colors.
- GUI: AX actions and PID-targeted events only, no System Events keystrokes.

## Notes
- Keys: never System Events `key code`/`keystroke` while the user works; they go to the frontmost app (was Safari). Post keys to the debug PID with `CGEvent.postToPid` (scratchpad keypid). Launch with `open -g` (background), AX actions (AXSelected, AXPress, set size) work without focus.
- GUI checks (2026-11-23, worked): select sidebar rows with `set value of attribute "AXSelected" of row N of outline` (outline = UI element 1 of UI element 1 of UI element 1 of UI element 1 of UI element 1 of window 1); System Events `click at` and CGEvent clicks do not select rows. Launch with `-ApplePersistenceIgnoreState YES`. Another agent's `xcodebuild test` starts a test-host Mel with the same debug bundle id and can quit the debug app: check `pgrep -x Mel` count == 1 before each step. Screens: CGWindowList by PID + `screencapture -l`.
- Earlier: System Events can't tell two "Mel" processes apart (`first process whose unix id is …` + `window 1` still hit /Applications/Mel.app on 2026-11-23). Rule (orchestrator): no System Events / GUI scripting at all while /Applications/Mel.app is running, debug pid or not. Screenshots come from the orchestrator/user. Earlier toolbar screenshots after 15:55 were of the user's app, not the debug build.
- While the user runs an install test of /Applications/Mel.app: don't launch the debug app, don't touch com.kaanf.mel defaults, and don't run the full xcodebuild test (MelTests are hosted by Mel.app, same bundle id). Only `cd MelKit && swift test`. Wait for the orchestrator to say the test is over.
- Debug builds use `com.kaanf.mel.debug` (core, 5cdeebf); never touch /Applications/Mel.app or `com.kaanf.mel` defaults. Earlier note: running the debug app touched the real `com.kaanf.mel` defaults. Pass fixtures as launch arguments (`--args -library '<hex>' -didShowWelcome YES`); `CFFIXED_USER_HOME` does NOT isolate `defaults write`.
- Views import only SwiftUI, MelSpec, UniformTypeIdentifiers (fileImporter). Sparkle only in App/. File pickers are `fileImporter`; chosen URLs go to AppState/SpecSession.
- Parsing runs off main via `parseDocument(_:kind:)` (@concurrent) in `.task(id: text)`; Review saves edits after 500 ms debounce via `session.save`.
- MarkdownParser is still a stub, so ReviewView/LivePreview previews render empty bodies until core 2.2; `ReviewDocument` and `MarkdownBlocksView` previews use block fixtures and show the real look.
- Previews compile with the build; I did not open them in Xcode's canvas, so visual rendering is unchecked.
- Approve is a FocusedValue (`\.approve`, plain FocusedValueKey; `@Entry` warns for closures). A ternary producing `approve : nil` crashed the compiler; use if/guard.
- Spec ready sheet opens when stage changes to `.done` while Review is shown; "Start Building…" in the Review toolbar reopens it.
- @AppStorage key: `didShowWelcome` (ui). Settings is one pane: Agents + Updates (no TabView, no scan-on-launch toggle).
- Commit-to-Git checkbox defaults to off.

## Blocked
- (nothing)

## Requests to orchestrator
- core is setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on the Mel target (separate commit); until then the icon set is in the catalog but not used.
- (none; Wave 1 requests are in CONTRACTS 884c099. "Story 3 of 5" is cut, step list stays.)
- core: ui calls `scanForAgent()` at launch, so AppState.init should not scan too.

## Questions for the user
- (none)
