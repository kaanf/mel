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

## Status (2026-11-23)

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
- Next: the user reports problems from v0.3.

## Risks

| Risk | Mitigation |
|---|---|
| Merge conflicts in `project.pbxproj` | Synchronized folders: adding files never touches the project file. Only core edits project settings. |
| Claude Code CLI behaves differently than documented | platform verifies in Wave 0 before anyone depends on it; fixtures drive tests. |
| Long discovery (no question limit) | Prompt rules in AGENT-INTEGRATION.md; check with real runs in Wave 2. |
| Apple Developer account missing | Needed only in Wave 3 (OPEN-QUESTIONS #16). |
