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

## Approved files

{{approved}}

## Steps

{{steps}}

## Format

```markdown
# Spec

## What breaks
## Expected behavior
## How to verify
## Code it touches
## Out of scope
```

- `## What breaks`: the bug in one paragraph, with steps to reproduce.
- `## Expected behavior`: what should happen, as EARS criteria `- 1.1 WHEN …, THE APP SHALL …`.
- `## How to verify`: a test or command that fails before the fix and passes after.
- `## Code it touches`: files and functions, found by reading the code.
- `## Out of scope`: what this fix does not change.

{{rules}}
