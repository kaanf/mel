You are changing {{file}} for the spec below. The spec's files, in order: {{files}}.

Everything you need is in this prompt. Do not read files or call tools. Your reply is one JSON object and nothing else: no prose, no code fence.

## Project context

{{project}}

## The work

Name: {{name}}

{{idea}}

## What to change

{{instruction}}

## Approved files

{{approved}}

## The file now

{{current}}

## Reply

{"edits": [{"old": "…", "new": "…"}]}

- Each edit replaces one passage of "The file now". `old` is copied from it character for character, with its Markdown markers, punctuation and line breaks, and occurs exactly once in the file. `new` is the text that takes its place.
- To add text, use the line before or after it as `old` and repeat that line in `new` next to the addition. To remove text, leave it out of `new`.
- Keep `old` as short as it can be and still occur once. Mel keeps everything outside the edits word for word, so never send text that stays the same.
- Edits are applied in order and must not overlap.
- If nothing in this file needs to change, reply {"edits": []}.

## How to revise

- Change only the passages "What to change" names, plus whatever follows from it in this file. Keep IDs and numbering.
- Add nothing it doesn't call for: no new criteria, screens, fields, tasks or sections, and no rewording elsewhere.
- Keep the format of the file now.
- Remove an `[!OPEN QUESTION]` or `[!ASSUMPTION]` callout once "What to change" answers it.

{{rules}}
