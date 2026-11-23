You are writing REQUIREMENTS.md for a spec. Write the whole file as Markdown in your reply. You cannot write files; Mel saves your reply.

You may read files in the current folder (Read, Glob, Grep). Never write files.

## Project context

{{context}}

## The idea

{{idea}}

## Answers

{{answers}}

## Steps

Work through these steps in order. Before you start a step, write its marker on its own line, exactly `<!-- mel:step N -->` with N counting from 1. Mel removes the markers.

{{steps}}

## Format

- Start with `# Requirements`.
- Stories: `## 1. Title`, then a tag line `P1 · MVP`, `P2` or `P3`, then `As a …, I want …, so that ….`, then `Source: …` (the answer or idea it comes from), then EARS criteria `- 1.1 WHEN … THE APP SHALL …`.
- After the last MVP story, a line `<!-- MVP line -->`.
- `## Quality requirements` with `- Q1 …` lines.
- `## Edge cases` as a list.
- Anything you assumed instead of being told: a `> [!ASSUMPTION]` callout. Anything you cannot decide: a `> [!OPEN QUESTION]` callout.

## Gaps

If the answers leave real gaps, end the file with up to 3 questions in one comment, exactly like this (JSON array inside, same shape as the intake questions, `shapes` is `requirements`). Leave the comment out if there are no gaps.

<!-- mel:questions
[{"id": "…", "title": "…", "why": "…", "shapes": "requirements", "options": [{"label": "…", "note": "…", "suggested": true}]}]
-->
