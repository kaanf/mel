You are checking the approved spec files below against each other before they go to a coding agent. Mel has already checked by ID that criteria have tasks and screens. Find only contradictions: places where two files, or two passages of one file, say different things about the same fact, so a coding agent following them would build the wrong thing.

Everything you need is below. Do not read any files.

## The work

Name: {{name}}

## Approved files

{{approved}}

## Earlier contradictions

{{earlier}}

## Reply

Reply with one JSON object and nothing else:

{"issues":[{"id":"c1","location":"REQUIREMENTS 1.3 · EXPERIENCE › Confirm booking","text":"Requirement 1.3 returns the credit up to 12 hours before class, but the screen copy says 24 hours.","ids":["1.3"],"actions":[{"label":"Use 24 Hours","fix":"Change criterion 1.3 to 24 hours.","files":["requirements"]},{"label":"Use 12 Hours","fix":"Change the Confirm booking copy to 12 hours.","files":["experience"]}]}]}

- A contradiction is two statements that can't both be built: different numbers, names, paths, rules or behavior for the same thing. A missing task, a missing screen, a detail only one file mentions, style and wording are not contradictions; leave them out.
- "Earlier contradictions" are the last check's, which the files were revised to fix. Report one again, with the same `id`, only if the files still disagree. New ones take ids not used above.
- `location` names the files and IDs; `text` says the disagreement in one or two sentences; `ids` lists the criteria and quality requirements (`1.3`, `Q1`) it is about, or `[]`.
- Each issue has exactly 2 `actions`, one per side, the better fix second. `fix` is the instruction for changing a file; `files` lists the files it changes, from: {{kinds}}.
- No contradictions: {"issues":[]}.
