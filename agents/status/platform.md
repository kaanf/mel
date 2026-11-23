# platform status

Wave: 0 (done, merged to main)
Updated: 2026-11-23

## Done
- 1.1 CLI verified on 2.1.311, findings in `docs/research/CLAUDE-CODE-CLI.md`, 4 new fixtures in `docs/research/fixtures/` (commit 29e8cd5)
  - `claude auth status`: JSON, free, exit 0 signed in / 1 signed out, `loggedIn` + `authMethod`. Login: `claude auth login`.
  - `--include-partial-messages`: `stream_event` with raw API events, text in `content_block_delta`/`text_delta`. Whole `assistant` messages still arrive, so take text from deltas only.
  - `--append-system-prompt` works with the read-only vector.
  - Discovery-style JSON-only answer with `Read,Glob,Grep`: bare JSON in `result.result`, parses directly.
- 1.2 `Mel/Agent/ShellPath.swift` replaces core's stub, `nonisolated`, contract signature unchanged. Rebased on origin/main; `xcodebuild build test` green.

## In progress
- (nothing)

## Next
- Wave 1 (wait for orchestrator's Wave 1 message): first `git fetch origin && git rebase origin/main`. Code moves to `MelKit/Sources/MelAgent` and `MelSystem`, tests to `MelKit/Tests/...` (core does the move in 0.1b); follow CONTRACTS.md "Layers and dependencies": MelAgent imports only MelSpec, MelSystem imports nothing, `AgentStatus` lives in MelSpec. Then move fixtures to `MelTests/Fixtures/`, ShellPath tests, then 1.3 ClaudeCode, 1.4 AgentRunner.

## Notes
- ShellPath timeout: kill the shell, then drain the pipe non-blocking. A child left by a login script can hold stdout open, so `readDataToEndOfFile` would wait past 5 s (seen with a hanging test shell). Wave 1 test: `SHELL` pointing to a script that sleeps must return "" in about 5 s.
- `loginPATH()` isn't cached; each `find` runs the shell (~70 ms). Cache in the caller if it's called more than once per scan.
- `auth status` also needs `USER` in the environment, same as runs.
- Older fixtures contain `/Users/kaan/JojoDisposable/...` probe paths: a username, not a secret.

## Blocked
- (nothing)

## Requests to orchestrator
- Done by orchestrator: `docs/AGENT-INTEGRATION.md` updated. (Was: it still said "to verify" for auth status, the login command, `--include-partial-messages` and `--append-system-prompt`. All verified now: use `claude auth status` (read `loggedIn`; `authMethod` must be `claude.ai`), login with `claude auth login`, partial messages on (text from `text_delta` only, tool calls from `assistant` blocks), stage contract via `--append-system-prompt`.)

## Questions for the user
- (none)
