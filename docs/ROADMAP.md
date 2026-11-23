# Roadmap

Mel is built by three Claude Code agents working in parallel git worktrees, coordinated by an orchestrator (the main Claude Code session in the repo root). How the agents work together: [agents/README.md](../agents/README.md). Task details: [TASKS.md](TASKS.md).

## Agents

| Agent | Owns | Worktree | Branch |
|---|---|---|---|
| **core** | Xcode project, `MelKit/Package.swift`, `MelKit/Sources/MelSpec/`, `MelKit/Sources/MelStorage/`, `Mel/Session/` | `../mel-worktrees/core` | `agent/core` |
| **platform** | `MelKit/Sources/MelAgent/`, `MelKit/Sources/MelSystem/`, fixtures, `scripts/`, `docs/research/` | `../mel-worktrees/platform` | `agent/platform` |
| **ui** | `Mel/App/`, `Mel/Views/`, assets | `../mel-worktrees/ui` | `agent/ui` |
| **orchestrator** | `docs/`, `agents/`, `CLAUDE.md`, `README.md`, merges to `main` | repo root | `main` |

## Waves

Each wave ends at a gate. The orchestrator merges each finished branch into `main`, checks the gate, then tells every agent to rebase on `main` and start the next wave. Nobody starts the next wave early.

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

## Status (2026-11-23)

- Waves 0–3 merged to `main`. G0–G2 passed (G2's fake-script part covered by core's 5.1 EndToEndTests).
- v0.1 published as a GitHub **pre-release** (tag `v0.1`, notarized DMG). Install test on the user's own account (not a separate one): Gatekeeper ✓ (quarantine, offline), Claude Code found from Finder/Dock ✓, first spec end to end ✓ (`~/virtual-internet-cafe`, 4 approved files), notification ✓, handoff ✓. Steps 2–3 (no Claude Code / signed out) skipped; covered by previews.
- On `main` since v0.1: toolbar status text + padding (ui), Debug bundle id `com.kaanf.mel.debug` (core).
- Agents must never touch `/Applications/Mel.app` or the `com.kaanf.mel` defaults.
- Next: Wave 4.

## Risks

| Risk | Mitigation |
|---|---|
| Merge conflicts in `project.pbxproj` | Synchronized folders: adding files never touches the project file. Only core edits project settings. |
| Agents drift from each other's APIs | Contracts written down first ([agents/CONTRACTS.md](../agents/CONTRACTS.md)) and stubbed in Wave 0; changes only through the orchestrator. |
| Claude Code CLI behaves differently than documented | platform verifies in Wave 0 before anyone depends on it; fixtures drive tests. |
| Long discovery (no question limit) | Prompt rules in AGENT-INTEGRATION.md; check with real runs in Wave 2. |
| Apple Developer account missing | Needed only in Wave 3 (OPEN-QUESTIONS #16). |
