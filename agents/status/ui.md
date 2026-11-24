# ui status

v0.3 published (build 389); standing by for the user's problem reports
Updated: 2026-11-24

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

- B1 New Spec (`Views/NewSpec/NewSpecView.swift`, replaces NewSpecSheet), rebased on origin/main (048f078, core W7), on the v2 API `specFolder(name:size:project:parent:)` / `createSpec(…, parent:)`; v1 no longer used by ui (core may remove it). Full test green.
  - MainView shows it full-window while `isShowingNewSpec`; Esc cancels; Add Project… → A2 and Read Repo → A3 run SetupFlow from MainView (`setupStep`) and return to B1; A2 Back returns to B1 when a library exists.
  - Parts: `FlowLayout` (wrapping chips), `DesignSwitchStyle`; B1 tokens in Theme.Size; `TextStyle.naturalHeight`. Debug screens `newSpec`, `newSpecNoContext`, `newSpecQuickFix`, `newSpecProduct`, `newSpecEmpty`; previews for the same five states.
  - Decisions (user confirmed all, 2026-11-23): Quick fix fields go into the idea as "Happens now: …" lines (no separate session fields); Paste Log is a small sheet with a text editor (views can't read NSPasteboard); empty name → "Untitled Spec" (no name suggestion yet); "Save to" button chooses the parent (Product) or adds another project folder (Feature/Quick fix); project branch from `state.branches` (core); Link Issue hidden (V2 §2).
  - Compared against the mock top (1280 × 800) and bottom (debug `-scrollBottom YES` opens the scroll view at its end; scratchpad `tools/bottom.sh`): within 1–2 px. Fixed in the bottom pass: Save to path was squeezed to nothing, switch knob drew black, CSS min-height excludes padding (project and switch rows are 52 + 16). Known deviations: SwiftUI line breaking avoids one-word last lines ("new screens", "· TASKS" wrap one word earlier; no API); SF Mono 10 pt ~3 % wider than WebKit; mock wraps "Save to" onto two lines (mock artifact), we keep one line, so the path truncates a bit earlier. Quick fix, Product and no-context states checked visually (the mock only renders the Feature state).
  - Idea text area is a TextEditor (multi-line TextField ignores line height); it creates an off-screen 500 × 500 window, so the scratchpad `winid` now picks on-screen windows only.

- A4x First spec (`Views/Setup/FirstSpecView.swift`), SetupFlow `.firstSpec`, debug screen `firstSpec`, previews Empty / With idea. Compared at 1280 × 800: within 1–2 px; only deviation is SwiftUI's one-word-last-line rule in the placeholder wrap. Product only; locked Feature/Quick fix cards link to A2; name is fixed "Untitled Spec" (as drawn: "Mel suggests a name once you describe your idea"; no suggestion yet); drop adds files shown as B1 evidence chips (not drawn, B1's part); Start passes no project/parent, core creates `~/Developer/<slug>/`.
  - Shared with B1 now: `IdeaTextArea` (placeholder gets the 23 pt line height too, fixes B1's placeholder), `EvidenceChip`, `NewSpecView.examples`.

- B2 Intake (`Views/Discovery/DiscoveryView.swift` rewritten in v2 style), debug screen `intake` now uses `PreviewData.intake` (the mock's content). Compared at 1280 × 800: content column and inspector within ~1 px.
  - Shared parts restyled to v2: `StageStepper` (check / filled dot / ring, 16 pt lines; used by B2, B3), `RadioRow` (B2 option row; C2 FailureSheet uses it too, C2 not redone yet). New glyphs chevronRight, arrowRight, draftNow, inspector. Toolbar status is now `StatusPill` in `.principal` with `sharedBackgroundVisibility(.hidden)` (no system glass around it).
  - Behavior: no "You decide" option any more (not drawn); Decide Later answers `.agentDecides` (shown "Later · the agent decides" in Answered). Digits 1…N. Open questions (no options, not drawn) keep a 3-line answer field in the note field's look.
  - Deviations: Draft Now and the inspector toggle sit at the window's trailing edge above the inspector (system toolbar; mock puts them left of the inspector). Timeboxed try 2026-11-23: the content `.toolbar` is already applied before `.inspector`; `.primaryAction` no change; a `ToolbarSpacer(.flexible)` in the inspector's toolbar moved them ~155 pt left but left the toggle straddling the inspector edge; an empty item there moved them back. Left at the trailing edge (orchestrator: leave it). "About 2 min left" hidden (V2 §2). Coverage `.later` shows "Round 2" with the ring (core added it). Understanding counts covered items (mock shows 4 of 10 with 3 covered). Long coverage labels truncate (mock wraps them out of their 28 pt rows). Note placeholder is "Note for the agent" (mock's is example text). Mock's B2 sidebar is the older wider variant; ours is variant (b).

- B3 Drafting (`Views/Drafting/DraftingView.swift` rewritten), debug screen `drafting` uses `PreviewData.draftingSession` (live text, activity, step 3). One compare pass: content rows match the mock.
  - Steps are the file's fixed `draftSteps` with `session.draftStep` (done / running / stopped / next); the mock's step labels are per-run text, ours are the fixed list. Pill: "Running · <current step>", count "n of m" (time estimate hidden), 2 pt bar = steps done. Pause hidden (V2 §2): only Stop. Stopped banner as drawn. Activity Log disclosure (link blue, rotating chevron, mono log box). Up Next from `spec.size.files`, last row ", then Analyze" when the size has Analyze. Live preview: compact reading of the parsed blocks (title, story headings, story text, criteria counted), caret after the last line while running; aligned top, follows the bottom as text grows.
  - Fixes shared with B2: StatusPill gets an ideal width (toolbars size by it; `statusPillCompact` 160 in narrow windows) and its progress bar no longer uses a GeometryReader; StatusDot's pulse is a phase animator (a repeating withAnimation in onAppear made the toolbar item bounce). Step rows use CSS min-height + padding (48 pt).
  - Core file touched: `AppState.preview(…, sessions:)` (preview only) so debug screens can show sessions with live text. Tell core in the final message.
  - Deviations: "Live Preview" header sits at the top of the inspector content, not in the toolbar row (our toolbar items sit over the inspector, see B2); Stop and the toggle at the trailing edge as in B2.

- B4 Review (`Views/Review/ReviewView.swift`, `Views/Markdown/MarkdownBlocksView.swift` rewritten), debug screen `review` uses `PreviewData.reviewSession` (the mock's REQUIREMENTS.md, 2 round-2 gaps). One compare pass: article matches the mock.
  - Article: H1 title, summary line, "Before you approve" (round-2 gaps → "Answer n Questions" sheet with B2's QuestionCard → `answerFollowUp`; assumptions and open questions jump to the box), stories with P1 · MVP badges, EARS criteria ("THE <system> SHALL" bold as one span), assumption box (Change… / Confirm), open-question box (Answer Now… → alert → `answerOpenQuestion`), dashed MVP line ("MVP LINE"), bullets. Approve no longer waits for assumptions ("You can approve anyway", V2). Toolbar: Preview / Edit Markdown icon segment, Show in Finder + Share group, Approve ⌘↩ without system glass. Edit mode: mono 12/18 editor in the article column.
  - `QuestionCard` is now internal and takes `onAnswer`. CalloutView removed (unused). New glyphs star, question, docLines, code, share; SVG parser handles C/c.
  - Hidden (V2 §2): review inspector, suggested changes (Accept/Reject) and their checklist row. MVP line text has no "· stories 4 and 5 are P2" (not in the parsed data).

- B5 Review EXPERIENCE.md: a variant of ReviewView (`isExperience`): subtitle "Flows, screens and states", only Approve in the toolbar, article 640, checklist row "n screens have no <state> state" (or "missing states") jumping to the table, no footer line. MarkdownBlocksView(`isExperience:`) draws numbered steps + following bullets as the flow diagram (nodes "Name (ids)", arrows, branch rows "Condition: Target (ids)") and the Screen/States/Criteria table with state chips (`!State` → "State missing", red outline). Debug screen `experience`. One compare pass: matches.
  - Deviations: hidden inspector (references, agent); branch "goes to Flow 2" form not supported (only "(ids)"); a paragraph under "Screens and states" renders as body text (mock draws its fixed hint as a caption).

- B6 Analyze (`Views/Analyze/AnalyzeView.swift`, new; MainView `.analyze`): stat tiles (adaptive min 190), issue cards (dot by kind, kind word + location, text, two actions → `session.apply`; second action medium weight), coverage matrix (Screen column only when rows have a screen mark), running and error states; toolbar Hand Off Anyway → `handOffAnyway`, "Fix n Issues with Claude Code" → `fixIssues`, both without system glass. Fixture `PreviewData.analysis` (the mock's data); debug screen `analyze`. One compare pass: matches.
  - Deviation: subtitle has no time ("· 12:31"; the result has no timestamp).

- B7 Spec ready (`Views/SpecReady/SpecReadyView.swift`, replaces SpecReadySheet): shown in the Analyze row when `stage == .done` (MainView), and as a sheet from Review's "Start Building…" (Quick fix). No toolbar row (title removed, content under the toolbar, 40 pt top). File tiles, P1 tasks (Start here / Parallel with n, Builds · reads, Verify, Copy Prompt → `task.prompt(requirements:)`), start command + Open in Terminal, Write AGENTS.md switch (on → `writeAgentsMD()`, starts off), Commit (→ `finish(commitToGit: true)`, git init confirm). Task prompts are written when the screen opens (`writeTaskPrompts`). Debug screen `ready`. One compare pass: matches.
  - Hidden (V2 §2): Keep the spec in sync, Use Codex Instead. Deviation: the AGENTS.md switch starts off (mock shows on); turning it on writes the file at once.

- C1 Refine (`Views/Refine/RefineView.swift`, new; MainView routes `.edited` files to it): banner, diff of the approved snapshot vs the file (`DiffLine.hunks`: heading above, changed lines, one line after; the marker replaces a list dash as drawn), What this affects (`session.impact`, "Checking what changes here…" until it's back), Why did this change? (2-line editor; saved via `saveDecision(title: "Changed <File>", …)` before Keep/Refine), Keep Them as They Are → `keepAsIs`, Refine n Files → `refine`, Undo Change → `undoEdit`. Inspector: decisions newest first (newest accent box, replaced faded). Debug screen `edited`. One compare pass: matches.
  - Deviations: no Agent/Decisions tab row (Agent hidden, V2 §2); the decision title is "Changed <File>" (the mock's is a summary the agent would write).

- C2 Agent stopped (`Views/Failure/FailureSheet.swift` restyled, still a sheet from Drafting): logo with alert badge, title 15/20, explanation per stop reason, file list (approved ✓, stopped ✕ with "Stopped at step n of m / Steps … saved" from `draftStep`, not started ring), choices as RadioRows (new `insets:`), Show Details link, Not Now, primary (Resume Later → `resumeLater`, Sign In…, Resume, Open File). Debug screen `failure` draws the dialog in the window (sheets can't be captured); `stopped` shows it as the real sheet. One compare pass: matches.
  - Hidden (V2 §2): Continue now with Codex. System sheet instead of the drawn dialog shadow (Theme note).

- C3 Home (`Views/Main/HomeView.swift`, replaces EmptyLibraryView; MainView shows it when there are no specs): no toolbar row, how-it-works tiles, start cards (Fix a bug / Add a feature "Extend <project>." / Plan a new app → B1 with that size, `MainView.newSpecSize`), New Spec ⌘N. Card meta shows the file count only (time estimates hidden). Debug screen `home`. One compare pass: matches.

- C4 Settings › Agents (`Views/Settings/SettingsView.swift` rewritten): Claude Code card (tile, status, Location + Change…, Account + Open Terminal…), Detection (search path list with selectable rows, +/−, footnote), Updates group (not drawn; same look), Scan Now. Hidden: General/Specs/Advanced tabs, Codex card, per-agent switch (V2 §2), scan-on-launch switch (earlier decision: always scans). Debug screen `settings` draws the pane in the window. One compare pass: matches.

- Wave 7 (wiring), rebased on 4778c39 (core's writeAgentsFile / analyzedAt / impact title), full test green (227 passed, 0 failed):
  - Sidebar project row → A3 (`ProjectSetupView(readsOnAppear: false)`): saved context from `state.contexts` without a new run; no context → "Mel hasn’t read this repo yet." + Read Repo (disabled while the agent is busy). A3 failed read → row with Try Again (was silent). Change… → A2, Save and Start a Spec → B1.
  - Missing project folders (`missingFolders`, dropped with the v2 sidebar) are back as rows under the projects: click or Locate… → `fileImporter` → `locate`, Remove from List → `removeMissing`. Not drawn; project row look, secondary color. MainView keeps the library when only missing projects remain.
  - MainView follows the pipeline (FLOW.md "Approve → B3 drafts the next file"): when the shown spec's current row changes, the detail follows if the old current row was open or a run just started (drafting / analyze running).
  - B3 stopped banner shows `session.lastError` (a refused run: another spec running, Claude Code not ready). Core file: `SpecSession.run` clears `lastError` when a run starts (separate commit, tell core).
  - B7: switch starts on; Done = the screen disappears (library navigation or the Quick fix sheet's Done) → `finish(commitToGit: false, writeAgentsFile:)` unless Commit already ran. Quitting the app on B7 skips it.
  - B6 subtitle "· <analyzedAt time>". C1 title: core already moved `saveDecision(reason:for:)`.
  - Keys: all drawn shortcuts were already bound (↩ Welcome/Continue, digits in Discovery, ⌘↩ A3/B1/A4x buttons + Approve menu, ⌘N). Window key equivalents run before the menu bar, so the disabled Approve item doesn't take ⌘↩ from B1/A3/A4x. ⌘N is now off during Lane A (no projects).
  - Previews: A3 Failed / Sidebar saved context / Sidebar not read yet; Sidebar Missing project.
  - Not run: a real Claude Code run through the Debug app (platform's real-run check).

- Wave 7 real-run bugs (docs/research/W7-REAL-RUN.md), full test green (227 passed, 0 failed):
  - 1: MainView shows one SetupFlow for first run and B1's Add Project/Read Repo; `setupStep` latches on appear, so `addProject` no longer swaps A2→A3 for the library.
  - 4/5: Live Preview uses `session.documents[kind]` when stopped; lines render through `MarkdownBlocksView.inline` (now static, shared).
  - 6: B7 title + "Builds … · reads …" inline Markdown; Verify only strips backticks (inline Markdown italicised `*Booking*` globs).
  - 7: list items after a task attach to it (`details`) and render as caption lines under the title. A non-indented list right after tasks would attach too (the parser drops indentation); not seen in TASKS.md.
  - 8: Review for `.stale`: banner (not drawn, B3 stopped-banner look) with Keep as It Is → `keepAsIs`, Refine n Files → `refine`; pill "Out of date · <edited file> changed"; Approve only for `.review`. B7 intro counts approved / edited / out of date / "Analyze needs a rerun" and points at the edited file. No core change needed (spec.docs has it). Preview "Out of date".
  - 10: B5 has the Preview/Edit and Finder/Share buttons; flow arrows lead their node.
  - 11: no change. AX audit of all 17 debug screens (scratchpad `axbuttons`, PID-targeted AX reads): every app button has a label in AXDescription (AXTitle stays empty, as SwiftUI does for custom labels): sidebar rows "PRODUCT.md, Approved", B1/Home cards, A3, C1 Keep/Refine/Undo. Only window traffic lights and scrollbar parts are unlabeled. SwiftUI builds the AX tree lazily: the first query of a fresh window returns empty groups, a second one is full.
  - Core's spec-name field (bug 2) not on main yet; wire it when it lands.

## Next
- Bug 2: core renames the spec in place (`spec.name`/`spec.folder` update), nothing to wire. B1/A4x use `Spec.untitledName` (committed, build only; not tested yet).
- v0.3 published (build 389). xcodebuild and the Debug app are allowed again. Stand by for the user's problem reports; d10d7e4 (`Spec.untitledName`) goes in with the next batch and gets tested with it.
- Comparison tooling: scratchpad of session 6a7afc62 (`tools/compare.sh <screen> <mock>`, `tools/bottom.sh` with `-scrollBottom`, `sbs`, `crop`, `winid` picks the ≥1000 pt window). Sheets can't be captured: debug screens `failure` and `settings` draw C2/C4 in the window.
- GUI: AX actions and PID-targeted events only, no System Events keystrokes.

## Notes
- Workflow (user, 2026-11-23): build B3, B4, B5, B6, C1–C4 back to back; incremental builds only to look at a screen; one compare pass per screen, no rounds for 1 px residuals; commit as I go, no per-screen merge requests; full `xcodebuild test` once at the end, then one ready-to-merge message.
- Small fixes: batch them with the next screen, no separate merge request (orchestrator, 2026-11-23).
- Before saying ready to merge: squash temp/wip commits (orchestrator, 2026-11-23).
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
