# CLAUDE.md

Guidance for coding agents working in this repo.

## Project

Keel: native macOS app (macOS 26+, shipped as a notarized DMG) that turns an idea into a four-file Markdown spec using the user's installed Claude Code. Codex is post-MVP; keep the `AgentAdapter` protocol but don't build Codex UI. Read `README.md`, then the doc for your task:

- What and why: `docs/PRODUCT.md`, `docs/REQUIREMENTS.md`
- Screens: `docs/UI.md`
- Architecture and data model: `docs/DESIGN.md`
- CLI integration: `docs/AGENT-INTEGRATION.md`
- Generated file format: `docs/SPEC-FORMAT.md`
- Work order: `docs/TASKS.md` (reference task IDs like `M2 2.3` in commits)
- Undecided points: `docs/OPEN-QUESTIONS.md` (don't silently decide them; ask)

## Priority

Performance, speed and the least complexity that works come first. Prefer the simplest code that meets the requirement: no speculative abstractions, no fallback layers, no "just in case" options. If a requirement looks expensive, say so and propose a cut instead of building machinery.

## Stack rules

- Swift 6 with strict concurrency. SwiftUI first; AppKit only when SwiftUI can't do it.
- `@Observable` for state, async/await for concurrency. No Combine, no architecture frameworks.
- **No third-party dependencies.** Ask before adding one.
- One app target, folders `App/ Agent/ Spec/ Storage/ Views/`. `Spec/` stays pure (no I/O, no SwiftUI).
- Keep the main actor free: process I/O, file writes and parsing run off it; throttle stream-driven UI updates.
- Use system components, semantic colors and SF Symbols. Do not copy hex colors or shadows from the HTML canvas.
- Every view has `#Preview`s for each state, built from fixtures.
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`).

## Invariants

- Keel is the only writer of `PRODUCT.md`, `REQUIREMENTS.md`, `DESIGN.md`, `TASKS.md`. Claude Code runs without write or shell tools.
- Never overwrite a user's edit; never change an approved file without a user action.
- All file writes are atomic.
- Agent CLI flags and output shapes are verified against fixtures in `Tests/Fixtures/`; update fixtures when a CLI changes.

## Commands

To be filled in once the Xcode project exists (build, test, run).
