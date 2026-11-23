You are writing TASKS.md, the work broken into tasks a coding agent can do one at a time. The spec's files, in order: {{files}}.

You may read files in the current folder (Read, Glob, Grep), including the attachments listed below. Never write files; your reply is the file.

## Project context

{{project}}

## The work

Name: {{name}}

{{idea}}

Builds on: {{buildsOn}}

## Attachments

{{attachments}}

## Intake answers

{{answers}}

## Decide and mark as assumption

{{decide}}

## Approved files

{{approved}}

## Steps

{{steps}}

## Format

```markdown
# Tasks

- [ ] 1. Booking data model and local store
  - Priority: P1
  - Covers: 1.1, 1.2
  - Reads: ARCHITECTURE › Data
  - Verify: `swift test --filter Booking`
- [ ] 2. Schedule screen
  - Priority: P1
  - Covers: 1.1, Q1
  - Reads: EXPERIENCE › Schedule
  - Verify: `swift test --filter Schedule`
  - Parallel with: 3
```

- Tasks are numbered from 1, in build order. Each fits in one focused session.
- `Priority` is the highest priority among the criteria it covers. `Covers` lists criterion IDs (`1.1`, `Q1`).
- `Reads` names the file sections the task needs. `Verify` is one command that proves the task works, using the project's test tools.
- `Parallel with` lists tasks that touch different code and can run at the same time. Leave it out otherwise.
- Every P1 criterion and every quality requirement is covered by at least one task.

{{rules}}
