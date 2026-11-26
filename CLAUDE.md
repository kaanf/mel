# CLAUDE.md

Guidance for coding agents working in this repo.

## Session start (every session, also after /clear)

Read `docs/ROADMAP.md` › Status (where things stand) and `git log --oneline -15` before doing anything else. Keep the Status section current.

## Project

Mel: native macOS app (macOS 26+, shipped as a notarized DMG) that turns an idea into a Markdown spec (one to five files by size) using the user's installed Claude Code. Codex is post-MVP; keep the `AgentAdapter` protocol but don't build Codex UI. Read `README.md`, then the doc for your task:

- What and why: `docs/PRODUCT.md`, `docs/REQUIREMENTS.md`
- Screens: `docs/UI.md`
- Architecture and data model: `docs/DESIGN.md`
- CLI integration: `docs/AGENT-INTEGRATION.md`
- Generated file format: `docs/SPEC-FORMAT.md`
- Work order: `docs/ROADMAP.md` waves and steps (reference the step in commits, like `8.5`). `docs/TASKS.md` is the v1 plan, kept as history
- The flow and its two product rules (say anything, token budget): `docs/V2.md` §0, `docs/design/v2/FLOW.md` › V2 sections
- Undecided points: `docs/OPEN-QUESTIONS.md` (don't silently decide them; ask)
- Plan and status: `docs/ROADMAP.md`

## Priority

Performance, speed and the least complexity that works come first. Prefer the simplest code that meets the requirement: no speculative abstractions, no fallback layers, no "just in case" options. If a requirement looks expensive, say so and propose a cut instead of building machinery.

## Stack rules

- Swift 6 with strict concurrency. SwiftUI first; AppKit only when SwiftUI can't do it.
- `@Observable` for state, async/await for concurrency. No Combine, no architecture frameworks.
- **No third-party dependencies.** Ask before adding one. Only exception: Sparkle 2 for updates, imported only in `App/` (approved 2026-11-23).
- Layers are modules. App target `Mel` = `App/ Views/ Session/`; local package `MelKit` = `MelSpec`, `MelStorage`, `MelAgent`, `MelSystem`. Dependencies point toward `MelSpec`; views import only SwiftUI, `MelSpec` and `UniformTypeIdentifiers` (`Theme.swift` also AppKit, for light/dark colors). Rules: `docs/DESIGN.md` › Project conventions. `MelSpec` stays pure (no I/O, no SwiftUI).
- Keep the main actor free: process I/O, file writes and parsing run off it; throttle stream-driven UI updates.
- Match the v2 design (`docs/design/v2/`) pixel for pixel in Light: its colors, spacing, padding, radii and type, kept as named tokens in one place. Every color token also has a Dark value (not drawn); views never branch on the appearance. Icons: SF Symbols where they match the drawn glyph.
- Every view has `#Preview`s for each state, built from fixtures.
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`).

## Invariants

- Mel is the only writer of the spec files (`PRODUCT.md`, `REQUIREMENTS.md`, `EXPERIENCE.md`, `ARCHITECTURE.md`, `TASKS.md`, `SPEC.md`, `DECISIONS.md`). Claude Code runs without write or shell tools.
- Never overwrite a user's edit; never change a Ready file without a user action: a card answer, Tell Mel, Remove, Update or Rewrite.
- Every change to a written file is a patch. A whole file is rewritten only from "Rewrite FILE".
- Token budget: no agent run for what Swift can do (scope moves, coverage by ID, guesses).
- All file writes are atomic.
- Agent CLI flags and output shapes are verified against fixtures in `MelKit/Tests/MelAgentTests/Fixtures/`; update fixtures when a CLI changes.

## Commits

Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`), optional area scope, task ID at the end: `feat(session): pipeline reducer (2.1)`.

## Commands

```sh
xcodebuild -project Mel.xcodeproj -scheme Mel -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData test -quiet
```

## Release

1. Move `## [Unreleased]` items in `CHANGELOG.md` into a new `## [x.y.z] · date` section, written for users (what changed for them, not commit subjects). Update the compare links at the bottom.
2. `TEAM_ID=SGWP227GBQ NOTARY_PROFILE=mel-notary scripts/release.sh`
3. `scripts/release-notes.sh x.y.z > notes.md` (that version's CHANGELOG section + requirements line), then `gh release create vx.y.z .build/release/Mel-x.y.z.dmg --target main --latest --title "Mel x.y.z" --notes-file notes.md`.
4. Commit `appcast.xml` + `CHANGELOG.md`, push. Share the release link with the user together with the notes.
