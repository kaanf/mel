# Spec format

The Markdown contract for the files Mel generates. Agents are prompted with this contract, and the app parses it to drive the review UI (counts, assumptions, open questions, links between tasks and criteria). Keep files readable in any Markdown viewer.

## Folder layout

```
<project>/
└── specs/
    ├── PRODUCT.md
    ├── REQUIREMENTS.md
    ├── DESIGN.md
    ├── TASKS.md
    └── .mel/
        └── state.json         pipeline state, questions/answers, session id
```

Deleting `.mel/` loses the pipeline state and history, never the spec itself.

The spec folder defaults to `<chosen folder>/<project-slug>/specs`, for example `~/Developer/yoga-studio-booking/specs`.

## Shared conventions

- One `#` heading per file: `# Product`, `# Requirements`, `# Design`, `# Tasks`.
- Sections use `##`. Numbered sections (`## 1. Book a class`) are stable IDs.
- Callouts use GitHub alert syntax with two custom types:

```markdown
> [!ASSUMPTION]
> The waitlist is first come, first served.

> [!OPEN QUESTION]
> What happens to unused credits when a pack expires?
```

  GitHub renders unknown alert types as plain block quotes, which is acceptable. An assumption is removed from the file (the text stays, the callout wrapper goes) when the user confirms it; "Change…" replaces the text and removes the wrapper.

- No HTML, no front matter in the four files. Everything the next agent needs is in the prose and callouts.

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

User stories with EARS acceptance criteria. IDs are `<story>.<criterion>`.

```markdown
# Requirements

## 1. Book a class

As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

- 1.1 WHEN a member books a class with free spots, THE APP SHALL reserve one spot, deduct one credit and show it under Upcoming.
- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead.

> [!ASSUMPTION]
> The waitlist is first come, first served.
```

Parsing rules:

- Story: `## <n>. <title>` followed by a paragraph starting `As a`.
- Criterion: list item starting `<n>.<m> ` containing `SHALL`.
- The review UI renders `WHEN`, `WHILE`, `IF`, `WHERE`, `THE APP SHALL` in bold small caps.

The canvas shows a "Source: your idea, Question 4" line per story. Not in the MVP: it needs per-story metadata for little value.

While drafting, the agent's first line is a plan (`5 stories`, `11 tasks`) that Mel strips from the file and uses for progress ("story 3 of 5").

## DESIGN.md

Six sections, in order (the failure screen refers to "section 3 of 6"):

```markdown
# Design

## 1. Architecture
## 2. Data model
## 3. Key flows
## 4. Interfaces
## 5. Security and privacy
## 6. Testing strategy
```

## TASKS.md

```markdown
# Tasks

- [ ] 1. Set up project skeleton
  - Covers: —
- [ ] 2. Weekly schedule screen
  - Covers: 1.1, 1.2
```

Every task lists `Covers:` with criterion IDs, or `—` for pure setup tasks. The app warns before approval if a criterion is not covered by any task.

## Suggestions (Later, not in the first version)

During review the agent never writes the file. When "Ask for changes" is added, it returns:

```json
{
  "reply": "I added criterion 1.3 for cancellations.",
  "suggestions": [
    {
      "find": "- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead.",
      "replace": "- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead.\n- 1.3 WHEN a member cancels at least 12 hours before class, THE APP SHALL return the credit."
    }
  ]
}
```

`find` must be an exact substring of the current file. Accept = replace the first occurrence. Reject = drop it. If `find` is no longer in the file, the suggestion shows as outdated. Suggestions are kept in memory only; they don't survive a relaunch.
