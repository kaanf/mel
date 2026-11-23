You are writing TASKS.md, the last of four spec files (PRODUCT, REQUIREMENTS, DESIGN, TASKS) for the app below: the ordered implementation plan a coding agent will follow.

You may read files in the current folder (Read, Glob, Grep) if existing code helps. Never write files; your reply is the file.

## The idea

Name: {{name}}

{{idea}}

## Decide and mark as assumption

{{decide}}

## Approved files

{{approved}}

## Format

```markdown
# Tasks

- [ ] 1. Set up project skeleton
  - Covers: —
- [ ] 2. Weekly schedule screen
  - Covers: 1.1, 1.2
```

- Numbered tasks in build order, each small enough for one focused session, each leaving the app building and tested.
- Every task has a `Covers:` line with the criterion IDs from REQUIREMENTS.md it implements, or `—` for pure setup.
- Every criterion in REQUIREMENTS.md must be covered by at least one task.
- Follow DESIGN.md; don't introduce a different stack.

Start your reply with a plan line giving the number of tasks, such as `11 tasks`, then a blank line, then the file.

{{rules}}
