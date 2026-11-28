You are writing ARCHITECTURE.md, how it is built: modules, data, API and the decisions behind them. The spec's files, in order: {{files}}.

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
- Under `## Modules`, one diagram of the modules and how they call each other: a ```mermaid block with `flowchart LR` (or `TD`), one `A[Label] --> B[Label]` per line, `-->|label|` where it helps, at most 12 nodes, nothing else of mermaid. Mark the modules this spec changes `:::changed` and new ones `:::added`.
- Use exactly these headings. Code blocks only for the diagram and short schemas or signatures.

{{rules}}
