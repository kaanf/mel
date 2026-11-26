# Tasks

> The v1 build plan (M0–M5), kept as history. Its `Covers:` IDs point at the v1 requirements, not at today's [REQUIREMENTS.md](REQUIREMENTS.md). Work since v0.2 is planned in [ROADMAP.md](ROADMAP.md) by wave and step.

Ordered so that the riskiest part (driving the real CLI) is proven first, and every screen can be built against fixture data before the pipeline is wired. `Covers:` lists criteria from [REQUIREMENTS.md](REQUIREMENTS.md).

## M0 · Foundation

- [ ] 0.1 Create Xcode project: one app target + one test target, macOS 26, Swift 6 strict concurrency, Hardened Runtime, no sandbox, folders as in DESIGN.md › Project layout.
- [ ] 0.1b Move Spec, Storage, Agent, System into the local package `MelKit` (one module each, one Swift Testing target each); app target keeps App, Views, Session; enforce the dependency rules in CONTRACTS.md › Layers and dependencies.
  - Covers: —
- [ ] 0.2 App shell: `NavigationSplitView` with sidebar, empty detail, inspector toggle, Settings scene with four tabs, Welcome window scene.
  - Covers: 9.4, 9.5

## M1 · Agent spike (de-risk)

- [ ] 1.1 Verify what docs/research/CLAUDE-CODE-CLI.md leaves open (auth status subcommand, `--include-partial-messages`, `--append-system-prompt`, usage-limit records) against the installed Claude Code; move fixtures to `MelTests/Fixtures/` and add new ones.
  - Covers: —
- [ ] 1.2 Login-shell PATH resolver and executable search with extra paths.
  - Covers: 1.2, 2.4
- [ ] 1.3 `AgentAdapter` protocol and `ClaudeCode` adapter: detection, auth status, arguments, NDJSON parsing, stop reasons (fixture tests).
  - Covers: 1.1, 1.4, 1.5, 7.2
- [ ] 1.4 `AgentRunner` actor: Process in own process group, stdin prompt, line-split stdout stream, stderr tail, stop (INT → TERM), inactivity timeout. Tests with a fake `claude` script.
  - Covers: 5.6, 7.1
- [ ] 1.5 Integration test (opt-in, skipped by default) that runs one discovery turn and one drafting stage against real Claude Code.
  - Covers: —

## M2 · Spec core

- [ ] 2.1 Models and pipeline reducer with unit tests.
  - Covers: 4.8, 5.9, 6.7, 6.8
- [ ] 2.2 Line-based Markdown parser for our format: headings, paragraphs, lists, stories, criteria, callouts, tasks + Covers; uncovered-criteria check.
  - Covers: 6.3, 6.9, 8.1
- [ ] 2.3 Storage: create folder, atomic writes, `state.json`, existing-file check.
  - Covers: 3.4, 3.5, 5.7
- [ ] 2.4 File watcher: reload external edits; "Keep Mine / Use File" when the editor has unsaved changes.
  - Covers: 6.2
- [ ] 2.5 Library persistence with bookmarks, missing-folder handling, state restoration.
  - Covers: 9.1, 9.2, 9.3

## M3 · Screens on fixtures

Each screen gets `#Preview`s for every state shown on the canvas (minus the Later features).

- [ ] 3.1 Welcome window.
  - Covers: 1.1, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8
- [ ] 3.2 Settings › Agents (+ minimal General, Specs, Advanced).
  - Covers: 1.10, 2.1, 2.2, 2.3, 2.4
- [ ] 3.3 Sidebar library with spec/document rows and statuses.
  - Covers: 9.1, 4.11
- [ ] 3.4 New Spec sheet with validation and folder picker; New Spec disabled while Claude Code isn't Ready.
  - Covers: 1.9, 3.1, 3.2, 3.3, 3.4
- [ ] 3.5 Discovery view: stepper, idea card, answered list, question card with radio rows, keys 1–4, "You decide", note, Draft Now; coverage inspector.
  - Covers: 4.1, 4.2, 4.3, 4.5, 4.6, 4.7, 4.10, 4.13
- [ ] 3.6 SwiftUI renderer for the parsed blocks (`LazyVStack`; EARS keyword styling, callouts).
  - Covers: 6.1
- [ ] 3.7 Drafting view: status line + progress bar, step list, activity log, Up Next, Stop, stopped banner, live preview inspector.
  - Covers: 5.2, 5.3, 5.4, 5.5, 5.6
- [ ] 3.8 Review view: Preview / Edit Markdown toggle, Before you approve box, assumption blocks, Approve ⌘↩.
  - Covers: 6.1, 6.3, 6.4, 6.5, 6.6
- [ ] 3.9 Failure sheet.
  - Covers: 7.2, 7.3, 7.4, 7.6
- [ ] 3.10 Spec ready sheet.
  - Covers: 8.1, 8.2, 8.4

## M4 · Wire the pipeline

- [ ] 4.1 Prompt files and string-replacement builder (discovery, four documents, continue) with the completeness rule.
  - Covers: 4.9, 4.12, 4.14, 5.1
- [ ] 4.2 `SpecSession`: discovery loop with JSON output and a manual Retry on bad output.
  - Covers: 3.6, 4.4, 4.8, 4.9
- [ ] 4.3 Drafting: stream into a buffer, debounced file writes, throttled preview, progress from `##` count vs. plan line.
  - Covers: 5.1, 5.2, 5.7, 5.8
- [ ] 4.4 Review actions: in-app edits, confirm/change assumption, approve and unlock next.
  - Covers: 6.2, 6.4, 6.5, 6.6, 6.7, 6.8
- [ ] 4.5 Recovery: resume from partial with `--resume`, notification at usage-limit reset, finish by hand.
  - Covers: 7.4, 7.5
- [ ] 4.6 Handoff actions: copy command, Open in Terminal, Git commit, Show in Finder.
  - Covers: 8.2, 8.3, 8.4
- [ ] 4.7 Notifications (ready to review, stopped, limit reset).
  - Covers: 5.8, 7.4
- [ ] 4.8 One agent run at a time across the app.
  - Covers: 9.6

## M5 · Ship

- [ ] 5.1 End-to-end tests with the fake script; manual runs with real Claude Code.
  - Covers: —
- [ ] 5.2 Accessibility pass (VoiceOver labels, keyboard navigation, Reduce Motion, Increase Contrast, Dark Mode).
  - Covers: 9.5
- [ ] 5.3 App icon; Developer ID signing; `scripts/release.sh`: archive → export → notarize + staple app → build DMG → notarize + staple DMG.
  - Covers: 9.7
- [ ] 5.4 Install test from the DMG on a clean macOS 26 user account (Gatekeeper, PATH detection from Dock launch, first-run flow).
  - Covers: 1.2, 9.7
- [ ] 5.5 Updates with Sparkle 2: EdDSA key, feed + public key in Info.plist, build number from the commit count, `release.sh` signs the DMG and writes `appcast.xml`; "Check for Updates…" in the app menu and Settings.
  - Covers: 9.8, 9.9

## Later (post-MVP)

See REQUIREMENTS.md › Later.

- [ ] L.1 Pause / Resume while drafting (SIGSTOP / SIGCONT).
- [ ] L.2 "Ask for changes" chat + inline `{find, replace}` suggestions; Review inspector tabs Agent, Questions, History.
- [ ] L.3 Time estimates.
- [ ] L.4 Parallel runs across specs.
- [ ] L.5 `Codex` adapter and agent choice UI. See AGENT-INTEGRATION.md › Later: Codex.
- [ ] L.6 Sparkle auto-updates.
