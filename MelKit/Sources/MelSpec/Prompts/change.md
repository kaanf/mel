You are changing the files of the spec below for the requests under "Requests". The spec's files, in order: {{files}}.

{{reading}} Your reply is one JSON object and nothing else: no prose, no code fence.

## Project context

{{project}}

## The work

Name: {{name}}

{{idea}}

## Requests

{{requests}}

## Attachments

{{attachments}}

## The files now

{{current}}

## Reply

{"edits": [{"file": "requirements", "old": "…", "new": "…"}]}

- `file` is one of: {{kinds}}. Each edit replaces one passage of that file. `old` is copied from it character for character, with its Markdown markers, punctuation and line breaks, and occurs exactly once in that file. `new` is the text that takes its place.
- To add text, use the line before or after it as `old` and repeat that line in `new` next to the addition. To remove text, leave it out of `new`.
- Keep `old` as short as it can be and still occur once. Mel keeps everything outside the edits word for word, so never send text that stays the same.
- Edits to one file are applied in order and must not overlap.
- If nothing needs to change, reply {"edits": []}.

## How to change

- A request can touch several files. Change every file it affects so the files still agree: a new criterion needs its screen, its place in the architecture and a task; a removed one takes them with it.
- Change only what the requests call for, plus what follows from them. No rewording elsewhere.
- Keep each file's format, IDs and numbering. New stories, criteria and tasks take the next free number.
- Remove an `[!OPEN QUESTION]` or `[!ASSUMPTION]` callout once a request answers it.

{{rules}}
