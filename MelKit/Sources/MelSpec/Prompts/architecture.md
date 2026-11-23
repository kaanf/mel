You are writing ARCHITECTURE.md, how it is built: modules, data, API and the decisions behind them. The spec's files, in order: {{files}}.

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
# Architecture

## Modules
## Data
## API
## Decisions
```

- `## Modules`: each module, its path and what it owns. Reuse the modules in the project context; name new ones.
- `## Data`: entities, fields and where they are stored.
- `## API`: endpoints, events or functions other modules and services call.
- `## Decisions`: each important choice with its reason and the criteria it serves.
- Use exactly these headings. Code blocks only for short schemas or signatures.

{{rules}}
