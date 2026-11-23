# Working as a Mel agent

Read this first, then your own brief (`agents/core.md`, `agents/platform.md` or `agents/ui.md`), then [CONTRACTS.md](CONTRACTS.md). Plan: [docs/ROADMAP.md](../docs/ROADMAP.md).

## Setup

Each agent runs in its own git worktree on its own branch:

| Agent | Folder | Branch |
|---|---|---|
| core | `/Users/kaan/Projects/mel-worktrees/core` | `agent/core` |
| platform | `/Users/kaan/Projects/mel-worktrees/platform` | `agent/platform` |
| ui | `/Users/kaan/Projects/mel-worktrees/ui` | `agent/ui` |

The orchestrator works in the repo root on `main` and is the only one who merges.

## Rules

1. **Stay in your paths.** Edit only the paths your brief lists as owned. Need a change elsewhere? Write it under "Requests" in your status file and continue with something else.
2. **Contracts are fixed.** Types and signatures in CONTRACTS.md are shared. Implement them exactly. To change one, write a request in your status file; the orchestrator updates CONTRACTS.md and tells everyone.
3. **Simplest thing that works.** Performance, speed and low complexity come first (see CLAUDE.md). No dependencies, no speculative abstractions.
4. **One wave at a time.** Do only your current wave's tasks. When done, update your status file, commit, push, and stop. The orchestrator starts the next wave.
5. **Green before done.** Build and tests must pass on your branch before you report a task done.
6. **Never touch `main`.** Don't merge, don't push to `main`, don't rebase other agents' branches. When the orchestrator says so, rebase your branch on `origin/main`.
7. **Ask, don't guess, on product questions.** Write them in your status file. Decide technical details yourself.

## Commits

- Conventional Commits with your agent as scope and the task ID: `feat(core): pipeline reducer (2.1)`, `test(platform): runner stop and timeout (1.4)`, `fix(ui): stepper contrast (3.5)`.
- Small commits; push your branch after each: `git push origin agent/<name>`.
- End every message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Build and test

From your worktree root, once the Xcode project exists (after core's Wave 0 merge):

```sh
xcodebuild -project Mel.xcodeproj -scheme Mel -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData test -quiet
```

Before the project exists (Wave 0 only), type-check your files standalone:

```sh
xcrun swiftc -typecheck -swift-version 6 -target arm64-apple-macos26.0 <files…>
```

## Status file

Keep `agents/status/<name>.md` current. It's the only file in `agents/` you edit. Format:

```markdown
# <name> status

Wave: 1
Updated: 2026-11-24 14:10

## Done
- 2.1 models + reducer (commit abc1234)

## In progress
- 2.2 parser: stories and criteria done, callouts next

## Blocked
- (nothing)

## Requests to orchestrator
- CONTRACTS: need `DocKind.fileName` on the enum

## Questions for the user
- (none)
```

## Starting a session

The user opens a terminal in your worktree and runs `claude`. Your first prompt will be: "Read agents/README.md and agents/<name>.md, then start your current wave." At the start of every wave:

```sh
git fetch origin && git rebase origin/main
```
