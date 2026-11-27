# Roadmap

Mel was built in waves by three parallel Claude Code agents (core, platform, ui) and an orchestrator. That setup was retired on 2026-11-26; work now happens in a single session on `main`. The waves below are history. Task details: [TASKS.md](TASKS.md).

## Waves

Each wave ended at a gate.

```
Wave 0  Foundation        core: Xcode project + contract stubs
                          platform: CLI verification, PATH resolver
                          ui: shared components (no model dependency)
   │ G0: main builds; contracts compile in their modules; test targets pass
   ▼
Wave 1  Parts             core: models, reducer, parser, storage, prompts
                          platform: adapter, runner, system actions
                          ui: every screen on preview data
   │ G1: all three merged; unit tests green; every screen has previews
   ▼
Wave 2  Wiring            core: SpecSession end to end with AgentRunning
                          platform: notifications, detection in AppState, release script draft
                          ui: views bound to AppState / SpecSession
   │ G2: idea → 4 approved files with the fake claude script; stop + resume works
   ▼
Wave 3  Ship              core: end-to-end tests
                          platform: signing, notarization, DMG, clean-install test
                          ui: accessibility pass
   │ G3: notarized DMG installs and runs a real spec on a clean account
   ▼
 MVP
```

## Wave 0 · Foundation

| Agent | Tasks | Done when |
|---|---|---|
| core | 0.1 Xcode project; contract stubs from [agents/CONTRACTS.md](../agents/CONTRACTS.md) for every agent's types so all code compiles from day one | `xcodebuild … build test` passes on `agent/core` |
| platform | 1.1 verify open CLI points; 1.2 login-shell PATH resolver (pure Foundation, type-checked with `swiftc`) | Findings in `docs/research/CLAUDE-CODE-CLI.md`; new fixtures recorded |
| ui | Shared components: status badge, stepper, grouped row, radio row, callout, key hint (type-checked with `swiftc`, no model types) | Components compile standalone |

Merge order: core first (creates the project), then platform and ui rebase and merge.

**0.1b Modules (core, after platform's merge, before ui's):** move everything below the UI into the local package `MelKit` (`MelSpec`, `MelStorage`, `MelAgent`, `MelSystem`) per CONTRACTS.md › Layers and dependencies. Done when `main` builds and every test target runs from the `Mel` scheme. Then ui rebases and merges, and G0 is checked.

## Wave 1 · Parts

| Agent | Tasks |
|---|---|
| core | 2.1 models + reducer · 2.2 Markdown parser · 2.3 storage · 2.4 file watcher · 2.5 library · 4.1 prompt files |
| platform | 1.3 Claude Code adapter · 1.4 AgentRunner · 1.5 opt-in real integration test · System actions (Terminal, Finder, pasteboard, Git) |
| ui | 0.2 app shell · 3.1–3.10 every screen with `#Preview`s for each state, on preview data |

## Wave 2 · Wiring

| Agent | Tasks |
|---|---|
| core | 4.2 discovery loop · 4.3 drafting · 4.4 review actions · 4.5 recovery · 4.8 one run at a time |
| platform | 4.7 notifications · agent detection exposed through `AppState` · 4.6 handoff actions · first draft of `scripts/release.sh` |
| ui | Bind every screen to `AppState` / `SpecSession`; keyboard shortcuts; state restoration UI |

## Wave 3 · Ship

| Agent | Tasks |
|---|---|
| core | 5.1 end-to-end tests with the fake `claude` script |
| platform | 5.3 signing, notarization, DMG · 5.4 clean-install test |
| ui | 5.2 accessibility pass, Dark Mode, Reduce Motion, Increase Contrast |

## Wave 4 · Phased discovery (before MVP)

Found in the v0.1 install test (2026-11-23): Discovery asked 21 questions in no clear order, grew its topic list from 8 to 18, and never asked about the user experience. The user decided: do this **before** calling the MVP done; UX goes into DESIGN.md as a new section 1.

Decisions (already in the docs): REQUIREMENTS 4.1, 4.7, 4.12–4.14 · SPEC-FORMAT DESIGN.md now has 7 sections, `1. User experience` first · AGENT-INTEGRATION Discovery turn · CONTRACTS `Answer.text`, `CoverageItem.phase`, empty `options` = open question.

| Agent | Tasks |
|---|---|
| core | Model: `Answer.text`, `CoverageItem.phase` (decode old state.json without `phase` as `.product`). `DiscoveryTurn` JSON: `phase` per coverage item, `options` may be empty for an open question. Prompts: discovery.md phase by phase in file order, open question first in each phase, new topics only in the current or a later phase, UX questions in the Design phase when there is a UI; design.md writes `## 1. User experience` from those answers (7 sections, progress count 7). `answersText` renders free-text answers. Tests. |
| ui | Discovery: open question card (multi-line text field, Continue ↩, Skip → `.agentDecides`); keys 1–4 only for option questions. Inspector: coverage grouped by phase with per-phase counts. Previews for both. Verify the toolbar status padding/truncation (8dddc94) in the running Debug build (`com.kaanf.mel.debug`; never script the GUI while /Applications/Mel.app runs). |
| platform | Record one real Discovery run with the new prompt as a fixture (`claude-<version>-discovery-open.jsonl`) and add a parse test. |
| orchestrator | Merge core first (model + prompts), then ui. Then cut v0.1.1… or v0.2 with the toolbar fixes + phased discovery: `TEAM_ID=SGWP227GBQ NOTARY_PROFILE=mel-notary scripts/release.sh`, tag, `gh release create --prerelease`. User re-tests one real spec; then G3 is done. |

Gate G4: a real spec where Discovery goes Product → Requirements → Design → Tasks, each phase opens with an open question, and DESIGN.md starts with `## 1. User experience`.

## Wave 5 · In-app updates with Sparkle (before v0.2)

The user wants "Check for Updates…" with a full in-place update (decided 2026-11-23: Sparkle 2, the one approved dependency). It ships in v0.2 so that v0.2 is the last manual DMG install. Docs: REQUIREMENTS 9.8–9.9, TASKS 5.5, DESIGN › Distribution + Security, UI › Settings › Updates group, CONTRACTS (Sparkle only in `App/`).

| Agent | Tasks (in this order) |
|---|---|
| platform | 1. Generate the EdDSA key pair with Sparkle's `generate_keys` (login Keychain), export a backup file for the user to store, send the public key to the orchestrator. 2. After core's merge: `release.sh` passes `CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)` to the archive, and after the DMG is notarized runs `sign_update` and writes `appcast.xml` at the repo root (one item: version, build, DMG URL `https://github.com/kaanf/mel/releases/download/v<version>/Mel-<version>.dmg`, length, `sparkle:edSignature`, `minimumSystemVersion` 26.0). 3. After ui's merge: an end-to-end update test on this Mac with two local Release builds (build N installed in a throwaway folder, never /Applications; build N+1 DMG + appcast served from `python3 -m http.server`, feed overridden through the `SUFeedURL` default of the debug/test bundle only), proving download → signature check → replace → relaunch. Note it in `docs/research/`. |
| core | Add the Sparkle package to the `Mel` app target (exact version: the newest 2.x released at least two weeks ago). Info.plist: `SUFeedURL`, `SUPublicEDKey` (from platform), `SUEnableAutomaticChecks` = YES. `MARKETING_VERSION` 0.2. Update `MarkdownParserTests` counts for 9.8–9.9 and 5.5 (criteria 71, tasks 42). Only core edits project settings. |
| ui | `App/Updater.swift`: wraps `SPUStandardUpdaterController`, exposes `canCheckForUpdates`, `automaticallyChecksForUpdates`, `checkForUpdates()`. App menu "Check for Updates…" after About (`CommandGroup(after: .appInfo)`). Settings › Updates group (UI.md) built from plain values/closures, `#Preview`s. Then the pending toolbar check once /Applications/Mel.app is closed. |
| orchestrator | Merge core, then ui, then platform. Cut v0.2: `release.sh`, `gh release create v0.2 --prerelease` with the DMG, commit + push `appcast.xml`. User installs v0.2 by hand one last time; the next release proves the in-app update. |

Gate G5: a local Release build updates itself from a localhost feed to a higher build, and v0.2's `appcast.xml` is live on `main`.

## Wave 6 · v2 parts (target: [V2.md](V2.md))

core step 0 runs now, alongside the v0.2.1 icon. The rest starts after v0.2.1 ships, in parallel.

| Agent | Tasks |
|---|---|
| core | **0. Contract v2 stubs** (first, alone): models for size, the new `DocKind`s (product, requirements, experience, architecture, tasks, spec), statuses (`edited`, `stale`), question round, open questions, decisions, project/spec folders, analyze result, impact result, attachments; `AppState`/`SpecSession` v2 signatures with `preview(…)` factories. Push stubs, write the diff in your status; the orchestrator updates CONTRACTS.md and merges before ui and platform build on it. **Then:** reducer for the v2 pipeline (sizes, analyze, edited/stale, revise), parser for V2.md §6 formats, `SpecStore` layout (§3, approved snapshots, DECISIONS.md, project library scan), prompts (project context, one-shot intake, each file with step markers and round-2 trailer, revise, analyze, impact), per-task prompt files. Rewrite SPEC-FORMAT.md from V2.md §6. Tests. |
| platform | Fixtures from real `claude` runs for every new JSON shape (project context, intake, analyze, impact) and for a draft with step markers + trailer; check that the Read tool opens attachments (text, images) under current flags; `~/Developer` repo scan; Git commit with the new pathspecs (`specs/<slug>/` minus `.mel/`, plus `.mel/project/`). Update AGENT-INTEGRATION.md. |
| ui | `Theme.swift` tokens taken from `docs/design/v2/*.dc.html`; light-only appearance; every screen A1–C4 as a view, pixel-exact inside a real window, minus V2.md §2; `#Preview`s for every state drawn in the mock (from fixtures on core's stubs). |
| orchestrator | Merge core step 0 → update CONTRACTS.md → tell ui and platform to rebase. Merge core, platform, ui. Update REQUIREMENTS.md and UI.md from V2.md. |

Gate G6: all three merged; tests green; every v2 screen has previews; side-by-side check of each preview against its `.dc.html` at the same size.

## Wave 7 · v2 wiring and v0.3

| Agent | Tasks |
|---|---|
| core | `SpecSession`/`AppState` v2 end to end against `AgentRunning`; end-to-end tests with the fake script for Quick fix, Feature and Product (incl. round 2, analyze fix, refine, stop + resume). |
| ui | Wire every screen to the session; keyboard shortcuts as drawn (↩, ⌘↩, 1–4, ⌘N). |
| platform | Real-run check on this Mac (Debug build only): a Feature spec on an existing repo and a Product spec from an idea, start to handoff. Notes in `docs/research/`. |
| orchestrator | Merge core → ui → platform. Cut v0.3 (`release.sh`, release notes from CHANGELOG, `gh release create v0.3 --latest`, push `appcast.xml`); v0.2.x installs update in-app. |

Gate G7: v0.3 updates in-app from v0.2.1; the user runs one Feature and one Product spec end to end.

## Wave 8 · Simplified flow and token budget (target: [V2.md](V2.md) §0)

Single session on `main`. Steps 8.1–8.2 also help the current flow and can ship as v0.4.x. 8.3 onward ships once as **v0.5**, with no half flow. Open questions #26–#30 are settled before the step that needs them.

| Step | Work |
|---|---|
| **8.1 Patch engine** | `revise.md` → reply `{"edits":[{"old","new"}]}`; `MelSpec` applies them (pure, tested: exact match once, else unplaced). Refine, open questions, round 2 and analyze fixes use it. Unplaced → offer whole-file rewrite (OQ #25). Re-record fixtures for the new reply. |
| **8.2 Token readout** | Read `usage` from each run's `result` (`MelAgent`), sum per spec and step in `state.json` (OQ #26). Show it in the current toolbar to get real numbers before 8.3. |
| **8.3 Cheaper checks** | Analyze coverage in Swift (criterion → task, Q → task, screen → criterion by ID); the agent only looks for contradictions, with a short JSON reply. Removing a story: Swift finds its IDs in later files, a patch run removes the prose. |
| **8.4 Board core** | `MelSpec`, pure and tested, next to the lane pipeline: `Board.swift` (no `review`/`approve`; `nextStep` = draft → cards → one change run for the answers → next file, or "Write it now"; check after the last file; halt, resume, edit), one `Card` model for intake questions, round 2, open questions and check issues with free answers, `Change` (a patch across files, `change.md`), `Story.move` (scope as a direct edit of the tag line and the MVP line). |
| **8.5 Session and screens** | `SpecSession` runs the board (`nextStep` loop, Tell Mel = one change run, Update, Remove with Restore, unplaced → Rewrite, project context in the background); `Pipeline.swift`, the lane stages and the `revise`/`impact` prompts go. V2-0 Start (+0b), V2-1 New (local size guess, OQ #27), V2-2 Board (+4, 5, 7, 8, 9), V2-3 Ready (Build with Claude Code, OQ #28), V2-6 Settings › Specs. Sidebar groups Needs you / Building / Done. Retire the A1–C3 views. Pixel-exact, `#Preview` per state. |
| **8.6 Docs** | REQUIREMENTS, UI, DESIGN, SPEC-FORMAT, AGENT-INTEGRATION from V2.md §0. Invariant wording (OQ #29) in CLAUDE.md and DESIGN.md. |
| **8.7 Ship** | End-to-end tests with the fake script (Quick fix, Feature, Product: gating, Tell Mel, remove, unplaced → rewrite, stop + resume). Real run on this Mac, token total compared with v0.4. Cut v0.5. |

Gate G8: a Product spec uses fewer tokens than the same spec on v0.4; a Tell Mel change and a Remove run without rewriting a whole file; v0.5 updates in-app from v0.4.

## Status (2026-11-27)

- Waves 0–3 merged to `main`. G0–G2 passed (G2's fake-script part covered by core's 5.1 EndToEndTests).
- v0.1 published as a GitHub **pre-release** (tag `v0.1`, notarized DMG). Install test on the user's own account (not a separate one): Gatekeeper ✓ (quarantine, offline), Claude Code found from Finder/Dock ✓, first spec end to end ✓ (`~/virtual-internet-cafe`, 4 approved files), notification ✓, handoff ✓. Steps 2–3 (no Claude Code / signed out) skipped; covered by previews.
- On `main` since v0.1: toolbar status text + padding (ui), Debug bundle id `com.kaanf.mel.debug` (core).
- Agents must never touch `/Applications/Mel.app` or the `com.kaanf.mel` defaults.
- Wave 4 merged (core 5b9883b, ui ad7c055, platform 8f251a8); ui toolbar check waits for the user to quit /Applications/Mel.app.
- Wave 5 merged except platform's local update test (core f66608a + 95146bf, platform 0ebf1ba, ui 4e37bc9). Toolbar check done, no change.
- v0.2 published (tag v0.2 at 0a47fe9, build 242, notarized; appcast.xml live on main 98f0099). G5 passed.
- v0.2.1 merged to `main` (version 0.2.1; ui: sidebar ↑ from PRODUCT.md to Discovery, short "Needs you" status below ~860 pt). All agents standing by.
- 2026-11-23: v2 design adopted ([V2.md](V2.md), OQ #20–22). Phased discovery (Wave 4) is replaced by the short intake, so G4 is dropped.
- v0.2.1 published (build 264, notarized, honeycomb icon); appcast.xml on main. Waiting for the user to see the in-app update from v0.2.
- Wave 6: core and platform merged (core 0e57a16, platform 7ab5ba5). ui screens in progress (done: sidebar, pill, A1, A1x, A2, A3; next B1). Contract additions since: FoundRepository, A3 read/sources/branch/fileCount, allowsTools, B1 specFolder + createSpec parent (all in CONTRACTS).
- Wave 7 core (SpecSession/AppState v2) in progress. Open follow-ups for core: persist context.json, module-name note, analyze/impact without tools.
- Saved before shutdown: core cd39ee9 (WIP, MelTests session tests not yet v2, do not merge), ui a9d89e6 (next B1, A4x), platform 379ac91 (WIP: `--tools ""` analyze ran >400 s without finishing; check before mapping allowsTools).
- Wave 7 core merged (d62dad7, 184 tests green); CONTRACTS: finish async. ui moves B1 to v2 signatures, then core drops the v1 ones.
- W7 merged: core v1 API dropped + AppState.branches (6d4ca6e), ui B1 bottom pass (321dbef), platform allowsTools → `--tools ""` + no-tools re-recordings (a34c1db). User confirmed: sidebar project name + status; Quick fix fields go into the idea text; Paste Log sheet; empty name → "Untitled Spec".
- Wave 6 ui screens merged (dd2d320): B3–B7, C1–C4. G6 met except the side-by-side check (one pixel pass per screen done by ui). User decisions 2026-11-23: system toolbar placement kept (buttons over the inspector, inspector headers below the toolbar); B7 AGENTS.md switch on, written on Done; C1 decision title from the impact run; B6 shows analysis time. Workflow: agents test once per batch, one merge request.
- Wave 7: core adds writeAgentsFile / analyzedAt / ImpactResult.title; ui wires every screen + shortcuts; platform real run after.
- W7 real run (platform, docs/research/W7-REAL-RUN.md): 16 bugs fixed by core + ui; re-run cancelled by the user.
- v0.3 published 2026-11-24 (tag v0.3 at 9d718e7, build 389, notarized; appcast.xml on main 0a6e8d4). v0.2 → v0.2.1 in-app update confirmed by the user. ~/untitled-spec deleted.
- Spec.untitledName and the a11y labels on B1 / intake merged after v0.3.
- 2026-11-26: multi-agent setup retired (worktrees, `agent/*` branches and `agents/` removed; layer rules moved to DESIGN.md › Project conventions).
- 2026-11-26: spec language (English/Türkçe) on A1 + Settings › Specs, stored per spec, appended to every spec prompt (`language.md`); OQ #5 decided.
- v0.4 published 2026-11-26 (build 409, notarized DMG); spec language selection and assumption confirmation fix. appcast.xml updated for in-app updates.
- 2026-11-26: canvas V2 simplified flow chosen as the next target (OQ #23–25), with expressiveness and token budget as product rules. `docs/design/v2/` synced from the canvas (V2-0…V2-9, D1, updated Native-*). Wave 8 planned; OQ #26–30 open.
- 2026-11-26: 8.1 done. Revise runs reply with a `Patch` (`MelSpec/Patch.swift`), no tools, no stored session; unplaced → B4 alert "Rewrite FILE" / Cancel (`rewrite.md`, the old whole-file prompt). Real run recorded (`claude-2.1.311-revise.jsonl`: 2 edits placed, 14 s). 248 tests green. Left for 8.4/8.5: the drawn V2-7 state with the rewrite's cost, Cancel putting the request back in the box.
- 2026-11-26: 8.2 done, OQ #26 decided (output + uncached input). `AgentEvent.usage` from `result.usage`, summed in `Spec.tokens` per step (`questions`, each file, `checks`, `changes`); `TokenReadout` in the toolbar with a per-step popover. 260 tests green. Not counted: runs stopped before their `result`, and the project context run (per project, not per spec; revisit in 8.4 when it moves to the background).
- 2026-11-26: 8.3 done. `AnalyzeResult.coverage` (MelSpec, pure) builds rows, stats and `noTask` / `qualityNotCovered` issues by ID; `analyze.md` asks for contradictions only (`{"issues": [...]}` with `ids`), merged by `AnalyzeResult.add`. Re-recorded: 3.0k output tokens / 28 s against 6.9k / 58 s. `StoryRemoval` (MelSpec, pure, tested) finds a story's criteria, screens and tasks, cuts the story out of REQUIREMENTS.md and gives the patch instruction per later file; its session call and the V2-8 card come with 8.4/8.5. 268 tests green. Cuts: P2/P3 criteria need no task, `scopeCreep` is no longer produced, the Architecture column shows only for contradictions (no IDs to trace there).
- 2026-11-26: 8.4 done as the board's core in `MelSpec`; the session part of the old 8.4 moved into 8.5, because the lane views can't run on the new pipeline and go in the same step. `Stage.board` is new; the lane stages stay until 8.5, and the app still runs the lane flow. `change.md` recorded for real (9 edits placed, 2.6k output tokens). 290 tests green. OQ #31–33 opened with the defaults the code uses.
- 2026-11-26: OQ #27, #28, #31–33 decided as recommended. 8.5 session half done: `SpecSession` › Board runs `nextStep` (drafts, one change run for the answers, check), Tell Mel with Undo, unplaced → Rewrite / Cancel, scope moves, Remove and Restore, the edit banner's Update / Keep / Undo, Resume, Check again, Start Building; a board that was working when Mel quit waits for Resume. `BoardSessionTests` cover it with scripted replies (303 tests green). The lane methods and views are still there and still what the app shows.
- 2026-11-26: V2-2 Board built (`Mel/Views/Board/`: board, inbox, plan with Screens and Build order, file reader and editor, Tell Mel, Files, the stopped / edit / unplaced / result banners), with `#Preview`s and `-screen board…` fixtures; tokens in `Theme.swift` › V2 board. It shows for any spec in `Stage.board`; nothing creates one yet, so the app still runs the lanes. Checked against the mockup in the Debug build for the cards, asking and unplaced states; the open file, Screens, Build order, stopped and edit states are built but not yet compared side by side. Fixed on the way: a task's `Priority` / `Reads` / `Verify` lines now sit under the task in the formatted view (the case was unreachable).
- 2026-11-27: 8.5 done. The app runs the V2 flow only: V2-0 Start (+0b, `Views/Start`), V2-1 New (`Views/New`, size guessed by `SpecSize.guess`), the board, V2-3 Ready (`Views/Ready`), V2-6 Settings › Specs (Settings is now General / Agents / Specs tabs) and the V2 sidebar (project menu, Needs you / Building / Done, optional file rows). The project context is read in the background after Start (`AppState.startProject` → `readContext`), next to a spec's own runs. Gone: the lane views and their components, `Pipeline.swift`, the lane stages (`Stage` is `discovery` / `board` / `done`; a 0.4 spec in a lane stage decodes as `board`), the lane methods of `SpecSession`, `revise.md` / `impact.md` / `discovery.md`, `ImpactResult`, `DiscoveryTurn`. Tests moved to the board (210 green); `EndToEndTests` runs Quick fix, Feature and a lost-session resume through `fake-claude.sh`. OQ #34–35 opened with the defaults the code uses; OQ #29 still open.
- Notes for 8.6 / 8.7: settings keys are `fillGaps`, `showTokens`, `showSidebarFiles`, `commitSpec`, `writeAgentsFile`, `settingsTab`, `editorApp`, `currentProject`. `Spec.build` (`building` / `done`) drives the sidebar groups. Hidden as deferred: Codex, Default agent, Save specs to, "Ask me before an agent changes the plan", Settings › Advanced. Not counted in a spec's tokens: the project context run. Start, New, Ready, Specs settings and the board with the new sidebar were looked at in the Debug build (`-screen start`, `noAgent`, `new`, `newEmpty`, `ready`, `specsSettings`, `board…`), not yet compared pixel by pixel with the mockups. The product e2e (gating, Tell Mel, remove, unplaced → rewrite) is 8.7's.
- 2026-11-27: 8.6 done, OQ #29 decided ("Never change a Ready file without a user action"). REQUIREMENTS and UI rewritten for V2; DESIGN (runtime, data model, the board's pipeline, changes, context, testing), SPEC-FORMAT and AGENT-INTEGRATION (change runs, check, no revise / impact) updated; CLAUDE.md invariants, README and V2.md's header brought in line. V2.md §2, §5, §7 stay as lane history.
- Left over, found while writing the docs (cheap token and code cuts, not done because the prompts' fixtures would need re-recording): drafts still emit `<!-- mel:step N -->` markers and `SpecSession.draftStep` / `activity` are still kept, but the board shows neither; `Spec.buildsOn` and `Spec.coverage` are still sent to or read from the prompts, but New no longer asks for "Builds on" and nothing shows coverage topics. PRODUCT.md and TASKS.md still describe the v1 plan.
- 2026-11-27: 8.7, first part. `EndToEndTests.productOnTheBoard` runs a New product through `fake-claude.sh`: the intake naming the spec, gating on a draft's question, one change run for the answer, Mel's own missing-task card and its fix, an unplaced Tell Mel → Rewrite ARCHITECTURE.md, Remove, a free scope move, Start Building (12 runs, scripted in `Fixtures/e2e/v2/pr-*`). Lane-only fixtures removed. 210 tests green. `docs/TASKS.md` is marked as the v1 plan; the test that tied it to REQUIREMENTS.md is gone.
- 2026-11-27: prompt cleanup. Drafts no longer write `<!-- mel:step N -->` markers (the board shows no checklist; `DraftText` still strips them for sessions from before); "Builds on" is gone from the prompts and `Spec`; `SpecSession.draftStep` removed. `Spec.coverage` stays: its uncovered topics are what a draft is told to decide. Re-recorded for real: `intake`, `draft` (was `draft-steps`), `change`. The new REQUIREMENTS.md draft: 5.7k output tokens, 55 s.
- v0.5 published 2026-11-27 (build 424, notarized DMG; appcast.xml updated): the V2 flow. Not done before the release, by the user's choice: a real run of the new flow through the app, and gate G8's token comparison (v0.4 has no token readout, and no v0.4 spec on this Mac kept a total). First real spec on 0.5 is the check; problems from it come first.
- 2026-11-27, after v0.5, from the user's first look: sidebar 272 and inbox 340 wide; `FlowLayout` gives a chip longer than a line the line's width (chips ran under the inbox); card answers are full-width wrapping rows; a working line above the board's center (file, section reached, Watch, Stop) and a pulsing Writing dot; `Animation.board` / `AnyTransition.drop` on cards, banners, stories, the sidebar and screen changes; live preview throttled to 5 updates a second; Rename… in a spec's sidebar menu (shown name only). On `main`, not released.
- 2026-11-27: Mel sets the model per run (`AgentModel`, `--model`): Opus 5.5 for drafts and changes, Sonnet 5.5 for intake, check and the project context. On `main`, not released.
- 2026-11-27: project menu › Move to Trash… (`AppState.trashProject`, whole folder, confirmed, off while an agent runs); a gear on the sidebar's agent line opens Settings. On `main`, not released.
- v0.5.2 published 2026-11-27 (build 433, notarized DMG; appcast.xml updated): model per run, Move to Trash, Settings gear.
- 2026-11-27: Dark mode (OQ #21 changed): `NSRequiresAquaSystemAppearance` removed, every color token has a Dark value, neutral washes and rings go through `Color.ink`. Looked at in the Debug build with `-AppleInterfaceStyle Dark` (Start, Board, stopped, Ready, Settings › Specs). A New product's name is asked in a sheet after Start. On `main`, not released.
- 2026-11-27: one conversation per spec (OQ #36). Kingdom and Dynasty (Product, Turkish, 193 KB of files) used 993k tokens: 54% change runs, 34% drafts, 11% the check; about three quarters was the written files sent again uncached. Drafts, changes, rewrites and continues now resume `Spec.conversation` (Opus, Read/Glob/Grep on every turn); a prompt sends only files the conversation hasn't seen as they are now. Recorded for real: `resumed-change` (10.4k read from the cache, 1.6k counted). Not yet measured on a whole spec. Next, not started: length targets in the draft prompts. On `main`, not released.
- 2026-11-27: board and Ready lag on a large spec (reported on Kingdom and Dynasty's Ready). Views parsed the files on every body pass (`tasks` ~6 times on Ready, `stories` 4–5 times plus summaries on the board; 3–9 ms each in Debug). `SpecSession` now parses a file once when it changes (`blocks`, `tasks`, `stories`, summaries); Ready's task list is lazy. Not yet profiled in the app. On `main`, not released.
- v0.6 published 2026-11-27 (build 438, notarized DMG; appcast.xml updated): one conversation per spec, parse once per change, the V2-3 Build screen. First real spec on 0.6 measures the token change; first Check it on Kingdom and Dynasty tests the check runner.
- 2026-11-27: V2-3 Build from the user's new canvas screens (V2-3 redrawn, V2-10 added, FLOW.md › Build; synced to `docs/design/v2/`). `BuildStep` (MelSpec) groups TASKS.md into Run alone / At the same time / One after the other from `Parallel with` and the new `Changes:` field (tasks.md prompt and SPEC-FORMAT); `Spec.runs` holds each task's state; Check it runs `Verify` through `Check.run` (MelSystem, login shell, last 20 lines); the last task done moves the spec to Done (OQ #34 updated). ‹ Plan reopens the board (V2-10), Start Building returns. `ReadyView` replaced by `Views/Build/BuildView`; looked at in the Debug build (`-screen building`), not compared pixel by pixel. The tasks prompt change (`Changes:`) isn't re-recorded. On `main`, not released.
- v0.5.1 published 2026-11-27 (build 429, notarized DMG; appcast.xml updated): dark mode, a new product's name, Rename, the working line, wider columns, wrapping answers, motion.

- 2026-11-27: Tell Mel on Build (V2-11 to V2-14, synced from the canvas; OQ #37). `BoardTell` with `building` is pinned under the steps; "Tell Mel about this" adds a task chip (the request says "Found while building task N"). `TaskRun.prompt` keeps the prompt copied, so a change shows "Prompt changed · Copy again" or "Changed after done" (Mel never reopens a task); `Spec.retasked` keeps the task count and Building / Done right when a change adds a task. Cuts from the drawing (user's choice): no Updated tag, no check output chip, Check it off only on the chip's task. Looked at in the Debug build (`-screen buildWorking`, `buildChanged`, `buildUnplaced`), Dark only. 269 tests green. On `main`, not released.

## Risks

| Risk | Mitigation |
|---|---|
| Merge conflicts in `project.pbxproj` | Synchronized folders: adding files never touches the project file. Only core edits project settings. |
| Claude Code CLI behaves differently than documented | platform verifies in Wave 0 before anyone depends on it; fixtures drive tests. |
| Long discovery (no question limit) | Prompt rules in AGENT-INTEGRATION.md; check with real runs in Wave 2. |
| Apple Developer account missing | Needed only in Wave 3 (OPEN-QUESTIONS #16). |
