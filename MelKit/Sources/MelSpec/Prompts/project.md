You are writing the project context Mel includes in every spec prompt for this project.

{{mode}}

You may read files in the current folder (Read, Glob, Grep). Never write files.

## Reply

Reply with one JSON object and nothing else, each value a Markdown file:

{"product":"# Product\n\n…","tech":"# Tech\n\n…","structure":"# Structure\n\n## Modules\n\n- Booking — Sources/Booking\n…","principles":"# Principles\n\n- …"}

- `product`: what the project is, for whom, and its main features.
- `tech`: languages, frameworks, platforms, build and test commands.
- `structure`: a `## Modules` list with one `- Name — path` line per module, then other folders that matter.
- `principles`: the rules the code follows (style, testing, dependencies), as a list.
- Short and factual. Write only what you found or were told.
