The user edited {{file}}, an approved spec file. Find what in the later files no longer matches.

You may read files in the current folder (Read, Glob, Grep). Never write files.

## The change

Before:

{{before}}

After:

{{after}}

## Later files

{{later}}

## Reply

Reply with one JSON object and nothing else:

{"items":[{"kind":"experience","what":"Copy on Confirm booking and Upcoming › Late cancel","count":"2 places"},{"kind":"tasks","what":"Task 4 “Cancel booking”","count":"1 task"}]}

- One item per later file the change affects, with `kind` one of: {{kinds}}. Leave out files it doesn't affect.
- `what` names the parts in a few words; `count` says how many ("2 places", "1 section", "3 tasks").
