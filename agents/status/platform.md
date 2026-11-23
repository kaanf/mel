# platform status

Wave: 5 merged (main 0a47fe9); standing by while the orchestrator cuts v0.2
Updated: 2026-11-23

## Done (Wave 3)
- fix: `fake-claude.sh` hang mode is `exec tail -n +1 -f` (plain `tail -f` started at the last 10 lines and lost `init`). `hangingRun` now pads with 10 unmapped records, so the hang tests fail without the fix (checked). Full `xcodebuild … test` green 3× in a row. Commit 2718415.
- 5.3 notarized end to end (2026-11-23, `TEAM_ID=SGWP227GBQ NOTARY_PROFILE=mel-notary scripts/release.sh`, no script changes needed):
  - DMG: `/Users/kaan/Projects/mel-worktrees/platform/.build/release/Mel-0.1.dmg` (1.3 MB, sha256 1f18385b41da5bb1fe49eedceb4b3f16c96616fcce65dc6b2acf2f138dda1b26; not committed).
  - Notary submissions Accepted: app 13aeb35d-16a6-46ff-a5a9-81e221330a09, DMG 630c97cf-265c-4ddb-bf6e-62d2fa0fba57.
  - `spctl -a -vv Mel.app` → accepted, source=Notarized Developer ID, origin=Developer ID Application: Kaan Firat (SGWP227GBQ).
  - `spctl -a -t open --context context:primary-signature -vv Mel-0.1.dmg` → accepted, source=Notarized Developer ID.
  - `xcrun stapler validate` → "The validate action worked!" on both; `codesign --verify --deep --strict Mel.app` ok.
- 5.3 `scripts/release.sh`: `TEAM_ID=SGWP227GBQ scripts/release.sh` archives with manual Developer ID signing (certificate picked by SHA-1 from the keychain), exports developer-id, `codesign --verify --deep --strict` on app and DMG, signs the DMG with a timestamp. Checks the notary profile (`NOTARY_PROFILE`, default `mel-notary`) up front; without it, it signs everything, then exits 1 with "Signed but not notarized … xcrun notarytool store-credentials mel-notary". Verified 2026-11-23: Authority Developer ID Application: Kaan Firat (SGWP227GBQ), secure timestamp, hardened runtime, no entitlements; `spctl -a -vv Mel.app` → rejected, `source=Unnotarized Developer ID` (expected until notarized). Unsigned path still works.
- 5.4 `docs/research/CLEAN-INSTALL.md`: checklist with steps and a results table (Gatekeeper incl. quarantine + offline launch, Dock PATH incl. custom `~/.zshrc` PATH and extra search path, first-run flow, first spec end to end, subscription-only check).

## Done (Wave 2)
- G1: edit-run fixtures now tested (`editRunsGiveOnlyStepsAndResult`: thinking, permission_denied and tool results stay silent; Edit/Write give bare "edit"/"write" steps). Commit 81dfa7c.
- `AgentRequest.systemPrompt` (init param, default nil) → `--append-system-prompt <text>`. 81dfa7c.
- 4.7 `Notifier`: `UNUserNotificationCenter`, future `at` → `UNCalendarNotificationTrigger` (wall clock, fires after sleep), else immediate. No delegate, so banners only show while Mel isn't frontmost (REQ 5.8 for free). No-op outside a `.app` bundle (swift test). 0d40ff1.
- 4.6: `Git.specPaths = ["specs", ":(exclude)specs/.mel"]` for the handoff commit (REQ 8.3); `Git.commit` is a no-op when the paths have nothing to commit (finishing twice doesn't throw). Test in a temp repo. 0d40ff1.
- `scripts/release.sh`: without `TEAM_ID` → ad-hoc signed (hardened runtime) `.build/release/Mel-<version>.dmg`, verified locally. With `TEAM_ID` + `NOTARY_PROFILE` → archive, export developer-id, notarize + staple app, DMG, codesign + notarize + staple DMG, `spctl` check (untested, needs the account). 0535bea.
- "No conversation found" → `.sessionNotFound` in `ClaudeCode.failures`; unknown-resume test updated.
- Rebased on main (c5c1487 + docs); `xcodebuild … test` green with the real Notifier.

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

## Done (Wave 4)
- `claude-2.1.311-discovery-open.jsonl`: first Discovery turn with the real discovery.md prompt and SpecSession's exact arguments/environment, recorded in a `mktemp -d` folder under /tmp; no secrets (`apiKeySource: none`, cwd under /tmp). Noted in CLAUDE-CODE-CLI.md › Fixtures.
- `discoveryFirstTurnIsOpenProductQuestion`: session first, deltas == result, decodes with `DiscoveryTurn.decode`, next question open (`options` empty) and `shapes == .product`, coverage covers all four phases.

## Done (Wave 5)
- 1: Sparkle EdDSA key pair made with `generate_keys` from Sparkle 2.10.1 (newest 2.x at least two weeks old; tarball sha256 1a856d2a…cf27, tools in /tmp/sparkle-2.10.1.OpwMKf/x/bin). Private key in the login Keychain; backup at ~/Desktop/mel-sparkle-private-key.txt for the user (never commit). Public key `N0XADslhn/EjchajsvI8XGFxZv1srmMIVnlrccel9o4=` sent to the orchestrator. sign/verify round trip passed.

- 2: release.sh passes `CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)` to both archive paths; after the notarized DMG it runs `sign_update` from the pinned package (`.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`, so no /tmp tools needed) and writes `appcast.xml` at the repo root. The unsigned run gave CFBundleVersion 227 and no appcast; the appcast block run alone on that DMG gave valid XML, correct length, and the signature verified.

- 3: local end-to-end update test ✓. Build 1000 → 1001 via localhost feed with bundle id com.kaanf.mel.updatetest, Developer ID signed, not notarized. Download, `OK: EdDSA signature is correct`, replace, relaunch all seen. /Applications/Mel.app and com.kaanf.mel untouched; test defaults removed. Write-up: docs/research/SPARKLE-UPDATE-TEST.md. Test folder /tmp/mel-update-test.Kz4oST left for manual deletion.

## Next
- Wait for the orchestrator's next wave.

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
- (none; Notifier gaps handed to core)

## Questions for the user
- (none)
