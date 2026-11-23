# platform status

Wave: 2 (all done except sessionNotFound, waiting on core's MelSpec case)
Updated: 2026-11-23

## Done (Wave 2)
- G1: edit-run fixtures now tested (`editRunsGiveOnlyStepsAndResult`: thinking, permission_denied and tool results stay silent; Edit/Write give bare "edit"/"write" steps). Commit 81dfa7c.
- `AgentRequest.systemPrompt` (init param, default nil) → `--append-system-prompt <text>`. 81dfa7c.
- 4.7 `Notifier`: `UNUserNotificationCenter`, future `at` → `UNCalendarNotificationTrigger` (wall clock, fires after sleep), else immediate. No delegate, so banners only show while Mel isn't frontmost (REQ 5.8 for free). No-op outside a `.app` bundle (swift test). 0d40ff1.
- 4.6: `Git.specPaths = ["specs", ":(exclude)specs/.mel"]` for the handoff commit (REQ 8.3); `Git.commit` is a no-op when the paths have nothing to commit (finishing twice doesn't throw). Test in a temp repo. 0d40ff1.
- `scripts/release.sh`: without `TEAM_ID` → ad-hoc signed (hardened runtime) `.build/release/Mel-<version>.dmg`, verified locally. With `TEAM_ID` + `NOTARY_PROFILE` → archive, export developer-id, notarize + staple app, DMG, codesign + notarize + staple DMG, `spctl` check (untested, needs the account). 0535bea.
- `xcodebuild … test` green.

## Done (Wave 0–1)
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
- When the orchestrator announces core's `StopReason.sessionNotFound` on main: rebase, add `("no conversation found", .sessionNotFound)` to `ClaudeCode.failures`, change `unknownResumeSession` test to expect `.failed(.sessionNotFound)`.
- Then Wave 3 (5.3 signing needs the Apple Developer account, 5.4 clean-install test).

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
- For core (`Mel/Session/`, I don't edit it):
  - `scanForAgent()`: `agent = .checking; agent = await adapter.detect(extraPaths: extraSearchPaths)`. Detection already runs its processes off the main actor (`Subprocess` is detached); allow ~10 s worst case (login shell + `--version` + `auth status`, 5 s timeouts each).
  - `signIn()`: when `agent` is `.ready`/`.notSignedIn(executable:)`, `try SystemActions.openInTerminal(command: adapter.loginCommand(executable:), in: FileManager.default.homeDirectoryForCurrentUser)`; user then taps Scan Again.
  - Notifications: `await Notifier.requestAuthorization()` once before the first run (e.g. in `start()`); `Notifier.post(title:body:)` when a file finishes or a run stops; `Notifier.post(…, at: resetsAt)` on `.usageLimit(resetsAt:)` with a date.
  - Handoff: `Git.commit(paths: Git.specPaths, message:, in: projectFolder)` off the main actor; `SystemActions.openInTerminal(command: startCommand, in: projectFolder)`; `startCommand` as in UI.md (`claude "Read specs/ and implement TASKS.md, task 1"`).
- CONTRACTS: add `static let specPaths: [String]` to `Git` (additive).
- Docs: DESIGN.md › Security says "`.mel/` is added to `.gitignore` when committing (setting)", but REQ 8.3 says always excluded, no setting. I implemented REQ 8.3 by pathspec and don't touch `.gitignore`; please align DESIGN.md.

## Questions for the user
- (for Wave 3) Apple Developer Team ID and a `notarytool store-credentials` profile name (OPEN-QUESTIONS 16).
