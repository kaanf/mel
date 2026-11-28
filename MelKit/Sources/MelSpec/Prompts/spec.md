You are writing SPEC.md, a short spec for one fix. The spec's files, in order: {{files}}.

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

## How the app works today

{{today}}

## Approved files

{{approved}}

## Steps

{{steps}}

## Format

```markdown
# Spec

## What happens now
## What should happen
## Must not change
## Check
## Code it touches
```

- `## What happens now`: what happens today, as numbered steps to reproduce it and what goes wrong. For a small change that isn't a bug, how it works today.
- `## What should happen`: numbered criteria `- 1 WHEN …, THEN ….`, one sentence each, that a test can check, each ending with its tag against how the app works today: `Changes B-2.1` when it fixes that rule's behavior, else `Adds <area>.md`.
- `## Must not change`: the behavior next to the fix that has to stay as it is, one bullet each, as `- B-2.1 WHEN …, THEN ….` with the rule's id when it is one of the rules above, else `- WHEN …, THEN ….` Read the code around the fix to find it. Answers to questions can add to it.
- `## Check`: the one command that fails before the fix and passes after, in backticks, and what it shows.
- `## Code it touches`: files and functions, found by reading the code.

{{rules}}
