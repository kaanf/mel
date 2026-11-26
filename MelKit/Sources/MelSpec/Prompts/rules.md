## Rules

- When information is missing, choose the best option and wrap that decision in a `> [!ASSUMPTION]` callout. Each topic under "Decide and mark as assumption" gets one where it applies:

> [!ASSUMPTION]
> The waitlist is first come, first served.

- An assumption is a full decision, written as a statement, not a question.
- Only a question whose answer would change the scope and that you cannot decide goes in a `> [!OPEN QUESTION]` callout. Never write TBD, TODO or placeholders.
- As you reach each step under "Steps", write `<!-- mel:step N -->` on its own line, with N the step's number. Mel hides these lines.
- After the file you may add up to 3 questions for the user whose answers would make the file better, as one trailing comment; `about` names the topic in two or three words. Leave it out when you have none:

<!-- mel:questions
[{"id":"q1","title":"Should a waitlist spot expire?","about":"full classes","why":"Sets criterion 1.2.","options":[{"label":"After 2 hours","note":"Frees the spot for others","suggested":true},{"label":"Never","note":"Simplest"}]}]
-->

- Output only the file's Markdown, the step lines and the optional trailer. No preamble, no closing remarks, no code fence around the file.
