# Mel

A native macOS app that turns a plain-language idea into a build-ready spec, written by the coding agent already installed on the user's Mac (Claude Code in the MVP) on the user's own account.

You write what you want in one box. Mel asks a few questions, writes the files one at a time, and shows them as a plan you can change in your own words. The output is plain Markdown in the project folder; the size of the work decides the files:

```
specs/<spec>/
├── PRODUCT.md        problem, users, scope                      (New product)
├── REQUIREMENTS.md   stories + EARS acceptance criteria         (Feature, New product)
├── EXPERIENCE.md     flows, screens and their states            (New product)
├── ARCHITECTURE.md   modules, data, API, decisions              (Feature, New product)
├── TASKS.md          tasks, each linked to criteria and a check (Feature, New product)
├── SPEC.md           one short spec                             (Quick fix)
└── DECISIONS.md      every answer and change, with its reason
```

Any coding agent can then build from it; Mel starts Claude Code on task 1.

## Status

Shipped: v0.4 (notarized DMG, in-app updates). On `main`: the simplified V2 flow for v0.5. Where things stand: [docs/ROADMAP.md](docs/ROADMAP.md) › Status. What changed for users: [CHANGELOG.md](CHANGELOG.md).

## Documents

| File | What it holds |
|---|---|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Problem, users, principles, MVP scope and non-goals |
| [docs/V2.md](docs/V2.md) | The simplified flow and its two product rules (§0) |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | User stories with numbered EARS acceptance criteria |
| [docs/UI.md](docs/UI.md) | The drawn screens (`docs/design/v2/`) mapped to views, and what differs |
| [docs/DESIGN.md](docs/DESIGN.md) | Architecture, modules, data model, the board's pipeline, persistence |
| [docs/AGENT-INTEGRATION.md](docs/AGENT-INTEGRATION.md) | How the app detects, runs, streams and recovers Claude Code |
| [docs/research/CLAUDE-CODE-CLI.md](docs/research/CLAUDE-CODE-CLI.md) | Claude Code CLI behavior verified on 2.1.311, with real recorded fixtures |
| [docs/SPEC-FORMAT.md](docs/SPEC-FORMAT.md) | The Markdown contract for the generated files |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Waves, gates and status |
| [docs/TASKS.md](docs/TASKS.md) | Milestones and implementation tasks, linked to criteria |
| [docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) | Decisions still to make, with a recommended default for each |
| [CLAUDE.md](CLAUDE.md) | Conventions for coding agents working in this repo |

## Source

Design canvas: https://claude.ai/artifact/EoySYJYRhntvx3G6u19EFd (copy in `docs/design/v2/`; read `FLOW.md` first).

## Tech stack (summary)

Swift 6 · SwiftUI · Observation · Swift Concurrency · Foundation `Process` · Swift Testing. macOS 26+. Distributed as a signed, notarized DMG (not the Mac App Store), because the app must launch user-installed CLIs. Details in [docs/DESIGN.md](docs/DESIGN.md).
