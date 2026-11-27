# Spec format

The Markdown contract for the files Mel generates (V2.md §3, §4, §6). Agents are prompted with it (`MelKit/Sources/MelSpec/Prompts/`), and `MarkdownParser` parses it to drive the board (the plan, the cards, the checks by ID). Each prompt's sample reply is checked against Mel's parser in `PromptTests`. Files stay readable in any Markdown viewer.

## Folder layout

```
<project>/
├── AGENTS.md                         optional; Mel owns only its <!-- mel:begin --> … <!-- mel:end --> block
├── .mel/project/                     project context, read once in the background, committed
│   ├── product.md  tech.md  structure.md  principles.md
└── specs/
    └── <spec-slug>/
        ├── PRODUCT.md …              the size's files, below
        ├── DECISIONS.md
        ├── prompts/task-01.md …      written at handoff
        └── .mel/                     app state, never committed
            ├── state.json
            ├── approved/<FILE>.md    each file as Mel last wrote it (Update's diff, Undo)
            └── attachments/          files added on New or to a Tell Mel request
```

Deleting `.mel/` loses the pipeline state, never the spec itself.

| Size | Files, in order |
|---|---|
| Quick fix | SPEC.md |
| Feature | REQUIREMENTS, ARCHITECTURE, TASKS |
| Product | PRODUCT, REQUIREMENTS, EXPERIENCE, ARCHITECTURE, TASKS |

## Shared conventions

- One `#` heading per file (`# Requirements`). Sections use `##`. Numbered sections (`## 1. Book a class`) and IDs (`1.1`, `Q1`, task `3`, `D-07`) are stable.
- Callouts use GitHub alert syntax with custom types. GitHub renders them as plain quotes.

```markdown
> [!ASSUMPTION]
> The waitlist is first come, first served.

> [!OPEN QUESTION]
> What happens to unused credits when a pack expires?
```

  An **assumption** is a decision the agent made, written as a statement; the board counts them as "small things Mel guessed". An **open question** is a gap the agent could not decide: it becomes a card, and its answer takes the callout out. One may stay in a file when the user chooses "Write it now" (OQ #32), for the coding agent to see. With "Let Mel guess small details" off, the agent makes no assumptions and every gap is an open question.
- No TBD, TODO or placeholders. No front matter.
- HTML comments are hidden by the parser. The only one kept in a file is `<!-- MVP line -->`.

## Draft stream markers

Mel strips this from the reply before it writes the file (and `<!-- mel:step N -->` lines, which drafts wrote before 0.5):

- An optional trailer at the very end, up to 3 questions the draft couldn't settle. Each becomes a card in "Mel needs you":

```
<!-- mel:questions
[{"id":"q1","title":"Should a waitlist spot expire?","why":"Sets criterion 1.2.","options":[{"label":"After 2 hours","note":"Frees the spot","suggested":true},{"label":"Never","note":"Simplest"}]}]
-->
```

## PRODUCT.md

```markdown
# Product

## Problem
## Users and roles
## Goals
## Scope
### In
### Out
## Platforms
## Constraints
```

## REQUIREMENTS.md

```markdown
# Requirements

## 1. Book a class

P1 · MVP
Source: your idea, Question 4 (cancellations)

As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

- 1.1 WHEN a member books a class with free spots,
  THE APP SHALL reserve one spot and deduct one credit.
- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead.

<!-- MVP line -->

## 2. Gift cards

P2
Source: Question 2 (payments)

As a member, I want to buy a gift card, so that I can give classes to a friend.

- 2.1 WHEN a member completes payment, THE APP SHALL email the gift card.

## Quality requirements

Source: Intake (privacy, speed, offline) and project principles

- Q1 THE APP SHALL open the weekly schedule in under 1 second on a mid-range phone.

## Edge cases

- Two members book the last spot at the same moment: one gets it, the other is offered the waitlist.
```

- Each story is a numbered `##` section with a tag line (`P1 · MVP`, `P1`, `P2`, `P3`), a `Source:` line, the "As a …" paragraph and EARS criteria `- <story>.<n> … THE APP SHALL …`. A criterion may wrap onto indented lines.
- `<!-- MVP line -->` follows the last MVP story.
- Quality requirements are `- Q<n> …`; edge cases are a plain list.

## EXPERIENCE.md

```markdown
# Experience

## Flow 1 · Book a class

Covers: 1.1, 1.2, 1.3

1. Schedule (1.1)
2. Class detail (1.1, 1.2)
3. Confirm booking (1.1)

- Class is full: Waitlist sheet (1.2)

## Screens and states

| Screen | States | Criteria |
|---|---|---|
| Schedule | Default, Empty week, Loading, Offline, Error | 1.1 |
| Class detail | Default, Full, Loading, !Error | 1.1, 1.2 |

## Visual direction

Calm and light, one accent color, large tap targets.
```

A state prefixed `!` is missing; the formatted view flags it.

## ARCHITECTURE.md

```markdown
# Architecture

## Modules
## Data
## API
## Decisions
```

## TASKS.md

```markdown
# Tasks

- [ ] 1. Booking data model and local store
  - Priority: P1
  - Covers: 1.1, 1.2
  - Reads: ARCHITECTURE › Data
  - Verify: `swift test --filter Booking`
  - Changes: Sources/Booking
- [ ] 2. Schedule screen
  - Priority: P1
  - Covers: 1.1, Q1
  - Reads: EXPERIENCE › Schedule
  - Verify: `swift test --filter Schedule`
  - Changes: Sources/Schedule
  - Parallel with: 3
```

`Changes` names the folders a task changes. V2-3 Build groups tasks marked `Parallel with` each other into one step: "At the same time" when their `Changes` don't overlap, "One after the other" when they do (a spec from before `Changes` counts as not overlapping). `Verify` is the command Mel runs on this Mac for Check it.

At handoff Mel writes `prompts/task-NN.md` per task: the task, the full text of each criterion it covers, what it reads, and the verify command.

## SPEC.md (Quick fix)

```markdown
# Spec

## What breaks
## Expected behavior
## How to verify
## Code it touches
## Out of scope
```

Expected behavior uses EARS criteria (`- 1.1 WHEN …, THE APP SHALL …`).

## DECISIONS.md

Written by Mel only, newest first: every answer, Tell Mel request, removal, rewrite and reason for an edit, in the user's own words. A decision that replaces another names it. A removed story's entry offers Restore on the board.

```markdown
# Decisions

## D-07 · Cancellation window 24 hours

Studio policy changed. Teachers need a full day to offer freed spots to the waitlist.

- Source: You · 2026-11-23
- Replaces: D-03
- Affects: 1.3
```

## Project context (`.mel/project/`)

`product.md`, `tech.md`, `structure.md`, `principles.md`. `structure.md` has a `## Modules` list of `- Name — path` lines. `principles.md` holds the rules every agent follows as `- <rule>` lines: Settings › Specs lists them, "Add Rule" appends one and the remove button takes one out.

## Agent JSON replies

| Run | Shape |
|---|---|
| Project context | `{"product","tech","structure","principles","read","sources"}`: four Markdown files, what was read, and where each file's content came from |
| Intake | `{"name","coverage":[{"label","state"}],"questions":[{"id","title","about","why","shapes","options":[{"label","note","suggested"}]}]}`; `name` names an untitled spec |
| Check | `{"issues":[{"id","location","text","ids","actions":[{"label","fix","files"}]}]}`: contradictions only, two actions each. Coverage, stats and missing-task issues are Mel's own checks by ID |
| Change | `{"edits":[{"file","old","new"}]}`: each `old` must occur exactly once in its file; all edits are placed or none |

Text around the JSON (a code fence) is ignored.
