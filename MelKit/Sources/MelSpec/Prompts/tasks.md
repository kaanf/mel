You are writing TASKS.md, the work broken into tasks a coding agent can do one at a time. The spec's files, in order: {{files}}.

You may read files in the current folder (Read, Glob, Grep), including the attachments listed below. Never write files; your reply is the file.

## Project context

{{project}}

## The work

Name: {{name}}

{{idea}}

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

## 1 · Foundation

- [ ] 1. Booking data model and local store
  - Priority: P1
  - Covers: 1.1, 1.2
  - Reads: ARCHITECTURE › Data
  - Verify: `swift test --filter Booking`
  - Changes: Sources/Booking

## 2 · Booking

- [ ] 2. Schedule screen
  - Priority: P1
  - Covers: 1.1, Q1
  - Reads: EXPERIENCE › Schedule
  - Verify: `swift test --filter Schedule`
  - Changes: Sources/Schedule
  - Parallel with: 3
```

- Tasks are numbered 1, 2, 3… in build order, with no gaps or repeats, counting on across phases. Each fits in one focused session.
- Group the tasks into phases under `## N · Name` headings, in build order: each phase ends with something the user can see working. Name it in 1 to 4 words.
- A reference to a task uses the number on its own `- [ ] N.` line. A callout about a task goes right under that task and names it by that number.
- `Priority` is the highest priority among the criteria it covers. `Covers` lists criterion IDs (`1.1`, `Q1`).
- `Reads` names the file sections the task needs. `Verify` is one command that proves the task works, using the project's test tools.
- `Changes` lists the folders the task changes, as paths from the project root.
- `Parallel with` lists tasks that need nothing from each other and change different folders, so they can run at the same time. Leave it out otherwise.
- Every P1 criterion and every quality requirement is covered by at least one task.
- A task builds a piece of the product together with its tests; never a task that only tests another task's work. Fewer, larger tasks beat many small ones: each task is a separate run.

{{rules}}
