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
