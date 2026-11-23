## Rules

- Do not make assumptions. Write only what the idea, the answers, the approved files and the project context say. Each gap becomes a `> [!OPEN QUESTION]` callout where it applies, including the topics under "Decide and mark as assumption":

> [!OPEN QUESTION]
> What happens to unused credits when a pack expires?

- An open question is one short, concrete question. Never write TBD, TODO or placeholders.
- As you reach each step under "Steps", write `<!-- mel:step N -->` on its own line, with N the step's number. Mel hides these lines.
- After the file you may add up to 3 questions for the user whose answers would close the most important gaps, as one trailing comment. Leave it out when you have none:

<!-- mel:questions
[{"id":"q1","title":"Should a waitlist spot expire?","why":"Sets criterion 1.2.","options":[{"label":"After 2 hours","note":"Frees the spot for others","suggested":true},{"label":"Never","note":"Simplest"}]}]
-->

- Output only the file's Markdown, the step lines and the optional trailer. No preamble, no closing remarks, no code fence around the file.
