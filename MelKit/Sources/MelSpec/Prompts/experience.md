You are writing EXPERIENCE.md, the user flows, the screens with every state they need, and the visual direction. The spec's files, in order: {{files}}.

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

- One `## Flow <n> · <name>` section per flow, with `Covers:` listing the criteria it serves, the screens in order as a numbered list with criteria in parentheses, and branches as a bullet list.
- `## Screens and states` is one table. Every screen lists what it shows when data is missing, slow, failing or offline. A state the criteria need but nobody has designed yet is prefixed `!`.
- `## Visual direction` is a short paragraph on tone, color and controls.

{{rules}}
