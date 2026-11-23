# Mel

A native macOS app that turns a plain-language idea into a build-ready spec, written by the coding agent already installed on the user's Mac (Claude Code in the MVP) on the user's own account.

The output is four plain Markdown files in the user's project folder, each reviewed and approved in order:

```
specs/
├── PRODUCT.md        problem, users, scope
├── REQUIREMENTS.md   user stories + EARS acceptance criteria
├── DESIGN.md         architecture, data model, ...
└── TASKS.md          implementation tasks, each linked to criteria
```

Any coding agent can then build from `specs/`.

## Status

Pre-development. Documents only, no Xcode project yet.

This repository previously held Jojo (Rust helper + SwiftUI shell). It was removed in favor of Mel; the Claude Code knowledge it verified was kept in `docs/research/`. The old code is in git history.

## Documents

| File | What it holds |
|---|---|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Problem, users, principles, MVP scope and non-goals |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | User stories with numbered EARS acceptance criteria |
| [docs/UI.md](docs/UI.md) | Screen-by-screen spec mapped from the design canvas to SwiftUI |
| [docs/DESIGN.md](docs/DESIGN.md) | Architecture, modules, data model, state machines, persistence |
| [docs/AGENT-INTEGRATION.md](docs/AGENT-INTEGRATION.md) | How the app detects, runs, streams and recovers Claude Code |
| [docs/research/CLAUDE-CODE-CLI.md](docs/research/CLAUDE-CODE-CLI.md) | Claude Code CLI behavior verified on 2.1.311, with real recorded fixtures |
| [docs/SPEC-FORMAT.md](docs/SPEC-FORMAT.md) | The Markdown contract for the four generated files |
| [docs/TASKS.md](docs/TASKS.md) | Milestones and implementation tasks, linked to criteria |
| [docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) | Decisions still to make, with a recommended default for each |
| [CLAUDE.md](CLAUDE.md) | Conventions for coding agents working in this repo |

## Source

Design canvas (8 artboards, macOS 26 HIG): https://claude.ai/artifact/45PrPjDYUrevUVJp2xNfUX

## Tech stack (summary)

Swift 6 · SwiftUI · Observation · Swift Concurrency · Foundation `Process` · Swift Testing. macOS 26+. Distributed as a signed, notarized DMG (not the Mac App Store), because the app must launch user-installed CLIs. Details in [docs/DESIGN.md](docs/DESIGN.md).
