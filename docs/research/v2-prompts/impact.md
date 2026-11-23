The user edited an approved file of a spec. Later files were built on it and are now out of date. Say what in each out-of-date file this change affects. Do not read other files. Never write files.

## The change in {{file}}

```diff
{{diff}}
```

## Out-of-date files

{{files}}

Reply with one JSON object and nothing else:

{"items": [{"kind": "…", "what": "…", "count": "…"}]}

One item per out-of-date file, in the order given, even if nothing changes there. `kind` is the file name lowercase without `.md` ({{kinds}}). `what` names the affected parts in a few words, like "Copy on Confirm booking and Upcoming › Late cancel", or "Nothing" if unaffected. `count` like "2 places", "1 task" or "0".
