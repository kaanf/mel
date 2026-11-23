# platform status

Wave: 1 (done, merged to main a427bca)
Updated: 2026-11-23

## Done
- Wave 0: 1.1 CLI verified, 1.2 ShellPath (merged to main).
- Fixtures moved to `MelKit/Tests/MelAgentTests/Fixtures/`, links in `docs/research/CLAUDE-CODE-CLI.md` updated. New: `claude-2.1.311-unknown-resume.jsonl` (no `init`, `result` with `errors[]` and no `result` field).
- 1.2 ShellPath tests (core's two + login PATH, dedupe/dirs, hanging shell times out in 5 s). `ShellPath` is now `public` (AppState needs `loginPATH()`).
- 1.3 `ClaudeCode` (commit d0b836e): detect = login PATH + extras → `--version` → `auth status` (`loggedIn` && `authMethod == "claude.ai"`). Arguments = verified read-only vector + `--include-partial-messages`. Environment = allowlist. Parse: text only from `text_delta`, steps from `tool_use`, failure table `ClaudeCode.failures`, API key in `init` → `failed(.crashed(apiKeyMessage))`.
- 1.4 `AgentRunner`: `posix_spawn` (own process group, only stdio inherited, default signals), prompt on stdin, stdout lines on a background thread, 64 KB stderr tail, inactivity watchdog, `stop()` = SIGINT then SIGTERM after 3 s. A rejected rate limit turns a later failure into `usageLimit(resetsAt)`.
- 1.5 `RealClaudeTests` runs only with `MEL_REAL_CLAUDE=1` (`cd MelKit && MEL_REAL_CLAUDE=1 swift test --filter RealClaudeTests`). Passed once on 2.1.311 (detect → ready, session, deltas, done).
- System: `SystemActions` (Terminal via a self-deleting temporary `.command` file, Finder, pasteboard), `Git` (commit 8534ae2). Tests: command-file content, Git in a temp repo.
- `xcodebuild … build test` green: 33 tests, including the MelKit ones.

## In progress
- (nothing)

## Next
- Wave 2 (wait for orchestrator's Wave 2 message), first `git fetch origin && git rebase origin/main`, then:
  - G1 item first: `claude-2.1.311-edit-run-short/long.jsonl` aren't used by any test. Add a parse test (tool_use and thinking records produce no text, steps are extracted) or delete them if obsolete.
  - Wire the accepted contracts (02c13b7): `AgentRequest.systemPrompt` → `--append-system-prompt` in `ClaudeCode.arguments`; map "No conversation found" → `StopReason.sessionNotFound` in `ClaudeCode.failures` once core adds the case in MelSpec; update the unknown-resume tests.
  - 4.7 Notifier (still a stub), detection in `AppState.scanForAgent()`, 4.6 handoff pieces, `scripts/release.sh` draft.

## Notes
- Running only MelKit is faster: `cd MelKit && swift test`.
- `fake-claude.sh <fixture> [hang | exit N]` runs via `/bin/sh` (`FakeClaude` adapter in AgentRunnerTests). Hang mode is `exec tail -f` on purpose: a shell waiting on a child swallows early signals, which made stop tests flaky. Fixture lines must end in a newline; the runner only delivers complete lines.
- `loginPATH()` uses `$SHELL -l -i` (per AGENT-INTEGRATION.md, so `.zshrc` PATH edits count). The runner calls it once per `AgentRunner` and prepends the executable's folder.
- Stopping the runner (or cancelling the stream's consumer) ends the stream with `failed(.user)`. Spawn failure throws `SpawnError`.
- `Git` is synchronous; call it off the main actor. `Git.isAvailable` is false without the Command Line Tools (`/usr/bin/git` alone is an installer stub).
- Older fixtures contain `/Users/kaan/JojoDisposable/...` probe paths: a username, not a secret.

## Blocked
- (nothing)

## Requests to orchestrator
- (none; `systemPrompt` and `sessionNotFound` accepted in CONTRACTS 02c13b7)

## Questions for the user
- (none)
