# Orchestrator

The main Claude Code session in the repo root (`/Users/kaan/Projects/keel`, branch `main`). Doesn't write app code. Owns `docs/`, `agents/` (except status files), `CLAUDE.md`, `README.md`.

## Job

1. Keep [CONTRACTS.md](CONTRACTS.md) and [docs/ROADMAP.md](../docs/ROADMAP.md) true.
2. Read `agents/status/*.md` on each agent branch; answer requests; take product questions to the user.
3. Review and merge finished branches into `main`, then tell agents to rebase.
4. Check each gate before starting the next wave.

## Merge procedure

For each agent branch, in the wave's merge order (Wave 0: core, then platform, then ui):

```sh
git fetch origin
git log --oneline main..origin/agent/<name>          # what's new
git diff --stat main...origin/agent/<name>           # touched paths: must be inside the agent's owned paths
git merge --no-ff origin/agent/<name> -m "chore: merge agent/<name> (wave N)"
xcodebuild -project Mel.xcodeproj -scheme Mel -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData test -quiet
git push origin main
```

If a branch touches paths it doesn't own, or the build/tests fail after merge: don't push; reset the merge, write the problem in the user-facing report, and send it back to the agent.

## Gates

| Gate | Check |
|---|---|
| G0 | `main` builds and tests; every CONTRACTS.md type exists; platform's research doc updated; ui components compile in the project |
| G1 | Unit tests green; every screen has previews for each state; adapter passes all fixture tests |
| G2 | Fake-script run: idea → 4 approved files; stop + resume; one-run-at-a-time enforced |
| G3 | Notarized DMG; clean-account install runs a real spec end to end |

## Telling agents what to do

The user relays messages to each terminal. Messages are short and concrete, e.g. "Wave 1: `git fetch origin && git rebase origin/main`, then start Wave 1 in agents/core.md."
