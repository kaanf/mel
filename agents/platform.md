# Agent: platform

You connect Mel to the outside world: finding and running Claude Code, parsing its stream, and the macOS integrations (Terminal, Finder, pasteboard, Git, notifications), plus packaging the DMG.

Read first: `CLAUDE.md`, `agents/README.md`, `agents/CONTRACTS.md`, `docs/AGENT-INTEGRATION.md`, `docs/research/CLAUDE-CODE-CLI.md`, `docs/DESIGN.md` (Interfaces, Distribution, Performance).

## You own

- `MelKit/Sources/MelAgent/`, `MelKit/Sources/MelSystem/` (from Wave 1; core stubs them in Wave 0)
- `MelKit/Tests/MelAgentTests/`, `MelKit/Tests/MelSystemTests/`, `MelKit/Tests/MelAgentTests/Fixtures/`
- `scripts/`
- `docs/research/`
- `agents/status/platform.md`

## Wave 0 · Foundation

You run in parallel with core, before the Xcode project exists.

- **1.1** Verify against the installed Claude Code (`/opt/homebrew/bin/claude`, 2.1.311) what `docs/research/CLAUDE-CODE-CLI.md` leaves open:
  - an `auth` status subcommand (exists? output signed in / signed out?),
  - `--include-partial-messages` (record a run: what do `stream_event` text deltas look like?),
  - `--append-system-prompt` with the read-only flags,
  - a JSON-only answer for a Discovery-style prompt with `--tools Read,Glob,Grep`.
  Run probes in a throwaway folder under `/tmp`, never in this repo. Keep each probe tiny (cost). Save recordings as `docs/research/fixtures/claude-2.1.311-<case>.jsonl`, check them for secrets, and update `CLAUDE-CODE-CLI.md` with what you observed. Don't try to trigger a real usage limit.
- **1.2** `MelKit/Sources/MelAgent/ShellPath.swift`: read the login-shell `PATH` (`$SHELL -l -c 'printf %s "$PATH"'`, 5 s timeout, take the last line), merge extra paths, find an executable. Pure Foundation; type-check with `xcrun swiftc -typecheck …`. Tests come in Wave 1 once the project exists.

Done when: research doc updated, fixtures committed, ShellPath type-checks. Commit, push, update status, stop.

## Wave 1 · Parts

Rebase on `main` first (the project exists now).

- Move the fixtures from `docs/research/fixtures/` to `MelKit/Tests/MelAgentTests/Fixtures/` and update the links in `CLAUDE-CODE-CLI.md`.
- **1.2** tests for ShellPath.
- **1.3** `MelAgent/ClaudeCode.swift`: `detect` (find → `--version` → sign-in check), `loginCommand`, `arguments` (verified read-only vector; `--resume` / `--no-session-persistence` from the request), `environment` (`HOME`, `USER`, `PATH`, `TERM=dumb`, `NO_COLOR=1`), `parse` (only the records AGENT-INTEGRATION.md maps). Fixture tests for every recorded case.
- **1.4** `MelAgent/AgentRunner.swift`: `Process` in its own process group, prompt on stdin, stdout split into lines off the main actor, stderr tail (64 KB), inactivity timeout, `stop()` = SIGINT then SIGTERM after 3 s. `MelKit/Tests/MelAgentTests/Fixtures/fake-claude.sh` replays a fixture (and can hang or exit non-zero) for tests.
- **1.5** opt-in integration test against the real CLI, skipped unless `MEL_REAL_CLAUDE=1`.
- `MelSystem/SystemActions.swift`, `MelSystem/Git.swift`: as in CONTRACTS.md (Terminal via a temporary `.command` file, no AppleScript). Tests where practical (Git in a temp dir).

## Wave 2 · Wiring

- **4.7** `MelSystem/Notifier.swift`: authorization, immediate and scheduled notifications.
- Agent detection inside `AppState.scanForAgent()`: you provide what core calls; coordinate the call site through the orchestrator if the contract needs to change.
- **4.6** handoff building blocks (command string for "Start building", Git commit of `specs/` with `.mel/` in `.gitignore`).
- First draft of `scripts/release.sh` (archive → export → notarize → staple → DMG → notarize → staple), runnable up to the signing step without credentials.

## Wave 3 · Ship

- **5.3** finish `scripts/release.sh` with Developer ID signing and notarization (needs the user's Apple Developer account; ask via your status file).
- **5.4** clean-install test checklist and run: Gatekeeper, PATH detection when launched from the Dock, first-run flow.

## Don't

- Don't edit `MelKit/Sources/MelSpec/`, `MelKit/Sources/MelStorage/`, `Mel/Session/`, `Mel/App/`, `Mel/Views/`, or project settings.
- Don't give Claude Code write or shell tools. Don't pass the app's whole environment to it.
- Claude Code runs on the user's **Claude subscription, never the API**: environment allowlist only (no `ANTHROPIC_*`, Bedrock or Vertex variables), and a run whose `init` record has `apiKeySource` other than `"none"` is stopped with an error. Test both. Your own probes in Wave 0 also run on the subscription: don't set API keys.
- Don't decode more of the stream than AGENT-INTEGRATION.md maps.
