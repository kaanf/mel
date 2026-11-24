You are checking the approved spec files below against each other before they go to a coding agent. Do not judge style; find what would make the build go wrong.

Everything you need is below. Do not read any files.

## The work

Name: {{name}}

## Approved files

{{approved}}

## Earlier issues

{{earlier}}

## Reply

Reply with one JSON object and nothing else:

{"stats":[{"value":"14 of 15","label":"criteria have a task"},{"value":"2 of 3","label":"quality requirements are covered"},{"value":"1","label":"contradiction between files"}],"issues":[{"id":"i1","kind":"contradiction","location":"REQUIREMENTS 1.3 · EXPERIENCE › Confirm booking","text":"Requirement 1.3 returns the credit up to 12 hours before class, but the screen copy says 24 hours.","actions":[{"label":"Use 24 Hours","fix":"Change criterion 1.3 to 24 hours.","files":["requirements"]},{"label":"Use 12 Hours","fix":"Change the Confirm booking copy to 12 hours.","files":["experience"]}]}],"coverage":[{"id":"1.3","text":"Cancel 12h before, credit returned","screen":"conflict","architecture":"covered","task":"covered","test":"covered"}]}

- `stats`: 3 or 4 counts. The first is always criteria with a task, counted in criteria (`1.1`), never stories; then such as quality requirements covered, screens that trace to a criterion, contradictions.
- "Earlier issues" are the last check's issues, which the files were revised to fix. Report one again, with the same `id`, only if the files still have it. Report a new issue only when a coding agent following the files would build the wrong thing; a detail the files settle consistently, or wording, is not an issue. New issues take ids not used above.
- `issues`: each one `kind` of `contradiction`, `noTask`, `qualityNotCovered` or `scopeCreep`; `location` names the files and IDs; `text` says the problem in one or two sentences.
- Each issue has exactly 2 `actions`, the better fix second. `fix` is the instruction for the revise run; `files` lists the files to change, from: {{kinds}}.
- `coverage`: one row per criterion and quality requirement (`1.1`, `Q1`) with a short `text`. Each of `screen`, `architecture`, `task` and `test` is `covered`, `missing` or `conflict`. `test` is `covered` when a task that covers the row has a Verify step, so it is `missing` only when `task` is; every row with a `missing` task is in a `noTask` issue. {{screen}}
- No issues: `"issues":[]`.
