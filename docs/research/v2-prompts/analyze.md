You are checking an approved spec before it is handed to coding agents. The files below were approved one by one; check them against each other. Do not read other files. Never write files.

{{files}}

Reply with one JSON object and nothing else:

{"stats": [{"value": "…", "label": "…"}], "issues": [{"id": "…", "kind": "…", "location": "…", "text": "…", "actions": [{"label": "…", "fix": "…", "files": ["…"]}, {"label": "…", "fix": "…", "files": ["…"]}]}], "coverage": [{"id": "…", "text": "…", "screen": "…", "architecture": "…", "task": "…", "test": "…"}]}

- `stats`: exactly 4: requirements (count of criteria), covered by tasks, issues, and open questions. `value` is a short number like "12" or "11/12"; `label` a few words.
- `issues`: real problems only, at most 8. `id` "i1", "i2", …. `kind` is one of `contradiction` (two files disagree), `noTask` (a criterion no task covers), `qualityNotCovered` (a quality requirement nothing addresses), `scopeCreep` (a task or design part no requirement asks for). `location` names where, like "REQUIREMENTS 1.3 · ARCHITECTURE › Store" or "TASKS 4". `text` one or two sentences. `actions`: exactly two ways to fix it; the second is the recommended one. `label` 1 to 3 words (like "Add Task"), `fix` the instruction for the agent that revises the files, `files` the files to revise: {{kinds}}.
- `coverage`: one row per acceptance criterion, in order. `id` like "1.3", `text` a short paraphrase. `screen`, `architecture`, `task`, `test`: `covered`, `missing` or `conflict`. {{screenRule}} `test` is `covered` when the covering task's Verify line tests the criterion.
