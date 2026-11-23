# CLAUDE.md

Guidance for coding agents working in this repo.

## Session start (every session, also after /clear)

Find out who you are from the working directory, then rebuild your context before doing anything else:

- **`/Users/kaan/Projects/mel-worktrees/<name>`** → you are agent `<name>` (core, platform or ui). Read `agents/README.md`, `agents/<name>.md`, `agents/CONTRACTS.md`, then `agents/status/<name>.md` (where you left off) and `git log --oneline -15`. Continue from "Next" in your status file.
- **`/Users/kaan/Projects/mel`** (branch `main`) → you are the orchestrator. Read `agents/ORCHESTRATOR.md`, `docs/ROADMAP.md`, and every agent's status on its branch: `git fetch origin && git show origin/agent/<name>:agents/status/<name>.md`.

Your status file is your memory. Keep it current.

## Project

Mel: native macOS app (macOS 26+, shipped as a notarized DMG) that turns an idea into a four-file Markdown spec using the user's installed Claude Code. Codex is post-MVP; keep the `AgentAdapter` protocol but don't build Codex UI. Read `README.md`, then the doc for your task:

- What and why: `docs/PRODUCT.md`, `docs/REQUIREMENTS.md`
- Screens: `docs/UI.md`
- Architecture and data model: `docs/DESIGN.md`
- CLI integration: `docs/AGENT-INTEGRATION.md`
- Generated file format: `docs/SPEC-FORMAT.md`
- Work order: `docs/TASKS.md` (reference task IDs like `M2 2.3` in commits)
- Undecided points: `docs/OPEN-QUESTIONS.md` (don't silently decide them; ask)
- Plan and multi-agent setup: `docs/ROADMAP.md`, `agents/README.md`, `agents/CONTRACTS.md`. If you are one of the agents (core, platform, ui), your brief is `agents/<name>.md`.

## Priority

Performance, speed and the least complexity that works come first. Prefer the simplest code that meets the requirement: no speculative abstractions, no fallback layers, no "just in case" options. If a requirement looks expensive, say so and propose a cut instead of building machinery.

## Stack rules

- Swift 6 with strict concurrency. SwiftUI first; AppKit only when SwiftUI can't do it.
- `@Observable` for state, async/await for concurrency. No Combine, no architecture frameworks.
- **No third-party dependencies.** Ask before adding one.
- Layers are modules. App target `Mel` = `App/ Views/ Session/`; local package `MelKit` = `MelSpec`, `MelStorage`, `MelAgent`, `MelSystem`. Dependencies point toward `MelSpec`; views import only SwiftUI, `MelSpec` and `UniformTypeIdentifiers`. Rules: `agents/CONTRACTS.md` › Layers and dependencies. `MelSpec` stays pure (no I/O, no SwiftUI).
- Keep the main actor free: process I/O, file writes and parsing run off it; throttle stream-driven UI updates.
- Use system components, semantic colors and SF Symbols. Do not copy hex colors or shadows from the HTML canvas.
- Every view has `#Preview`s for each state, built from fixtures.
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`).

## Invariants

- Mel is the only writer of `PRODUCT.md`, `REQUIREMENTS.md`, `DESIGN.md`, `TASKS.md`. Claude Code runs without write or shell tools.
- Never overwrite a user's edit; never change an approved file without a user action.
- All file writes are atomic.
- Agent CLI flags and output shapes are verified against fixtures in `MelKit/Tests/MelAgentTests/Fixtures/`; update fixtures when a CLI changes.

## Commits

Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`), agent name as scope when working as an agent, task ID at the end: `feat(core): pipeline reducer (2.1)`.

## Commands

```sh
xcodebuild -project Mel.xcodeproj -scheme Mel -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData test -quiet
```
