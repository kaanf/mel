You are preparing the intake for a {{size}} spec. The spec's files, in order: {{files}}. Ask the questions whose answers most change what those files say.

You may read files in the current folder (Read, Glob, Grep), including the attachments listed below. Never write files.

## Project context

{{project}}

## The work

Name: {{name}}

{{idea}}

## Attachments

{{attachments}}

## Topics to cover

{{topics}}

## Reply

Reply with one JSON object and nothing else:

{"name":"Class Pack Booking","coverage":[{"label":"Goal and success metric","state":"covered"},{"label":"Payments","state":"notYet","question":"payments"},{"label":"Edge cases","state":"later"}],"questions":[{"id":"payments","title":"How do members pay?","why":"Shapes checkout and the requirements for credits.","shapes":"requirements","options":[{"label":"Class packs bought in the app","note":"You mentioned buying class packs in your idea","suggested":true},{"label":"Paid at the desk, app only books","note":"No checkout in the app"}]}]}

- `name`: a short name for the work in Title Case, at most 4 words, such as "Class Pack Booking".
- `coverage` starts from "Topics to cover"; add topics the work needs. `state` is `covered` when the idea, attachments or project context already answer it, `notYet` when one of your questions asks about it (`question` is that question's `id`), else `later` (the draft settles it and may ask about it then).
- `questions`: about {{count}}, most important first, one per uncovered topic that matters. Never ask what the idea, attachments or project context already answer.
- Each question has 2 to 4 `options` with a short `note`; mark the best one `"suggested": true`. Use no options only for a question the user must answer in their own words.
- `shapes` is the file the answer mostly affects, one of: {{kinds}}.
