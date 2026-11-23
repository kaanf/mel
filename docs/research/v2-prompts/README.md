# Provisional v2 prompts

Written by platform to record the Wave 6 fixtures before core's prompts exist. core owns the real prompts in `MelKit/Sources/MelSpec/Prompts/`; take what helps, then re-record with the final text.

| Prompt | Fixture (`MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-…`) | Placeholders |
|---|---|---|
| `context.md` | `project-context.jsonl` | `newProject` |
| `intake.md` | `intake.jsonl` | `context`, `size`, `files`, `buildsOn`, `idea`, `attachments`, `topics`, `count` |
| `draft-requirements.md` | `draft-steps.jsonl` | `context`, `idea`, `answers`, `steps` |
| `analyze.md` | `analyze.jsonl` | `files`, `kinds`, `screenRule` |
| `impact.md` | `impact.jsonl` | `file`, `diff`, `files`, `kinds` |

`attachments.jsonl` used a two-line prompt asking for the ERROR line of a `.log` and a description of a `.png`.

The probe project was a small Swift package (FocusTimer: `TimerCore`, `SessionStore`, `FocusTimer` targets) with the Feature idea "short and long breaks plus a daily goal". Analyze and Impact ran on its REQUIREMENTS.md (from the draft run) plus a hand-written ARCHITECTURE.md and TASKS.md with planted issues (`config.json` vs `settings.json`, story 6 without a task, a sound task nothing asks for).

Re-record: `python3 -I record.py <prompt.md> <probe-folder> <out.jsonl> key=value key=@file …`. See [AGENT-INTEGRATION.md](../../AGENT-INTEGRATION.md) › Stage protocols for the shapes.

`probe/` holds everything the recordings used: the two probe folders and `inputs/` (filled placeholder values; `context.txt` is the project-context run's four files joined). **Copy `probe/` out of the Mel repo first** (e.g. into the session scratchpad and `git init` the copy): run inside this repo, Claude Code would also load Mel's own CLAUDE.md from the parent folders. Commands used, from the copy (`R` = this folder):

```sh
python3 -I $R/record.py $R/context.md focus-timer out/project-context.jsonl newProject=
python3 -I $R/record.py $R/intake.md focus-timer out/intake.jsonl context=@inputs/context.txt size=Feature \
  "files=requirements, architecture, tasks" "buildsOn=TimerCore, SessionStore" idea=@inputs/idea.txt \
  "attachments=- specs/breaks-and-goal/.mel/attachments/feedback.txt" \
  "topics=Main flows, Data and storage, Constraints, Milestones" count=3
python3 -I $R/record.py $R/draft-requirements.md focus-timer out/draft-steps.jsonl context=@inputs/context.txt \
  idea=@inputs/idea.txt answers=@inputs/answers.txt steps=@inputs/steps.txt
python3 -I $R/record.py $R/analyze.md focus-timer out/analyze.jsonl files=@inputs/files.txt \
  "kinds=requirements, architecture, tasks" "screenRule=This spec has no EXPERIENCE.md, so \`screen\` is null."
python3 -I $R/record.py $R/impact.md focus-timer out/impact.jsonl file=REQUIREMENTS.md diff=@inputs/diff.txt \
  files=@inputs/stale.txt "kinds=architecture, tasks"
python3 -I $R/record.py inputs/attach-prompt.md probe-attach out/attachments.jsonl
```

With core's prompts the placeholder names change; map them to the same inputs.
