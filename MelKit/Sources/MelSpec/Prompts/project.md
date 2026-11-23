You are writing the project context Mel includes in every spec prompt for this project.

{{mode}}

You may read files in the current folder (Read, Glob, Grep). Never write files.

## Reply

Reply with one JSON object and nothing else, each value a Markdown file:

{"product":"# Product\n\n…","tech":"# Tech\n\n…","structure":"# Structure\n\n## Modules\n\n- Booking — Sources/Booking\n…","principles":"# Principles\n\n- …","read":[{"label":"README.md","source":"Product summary"},{"label":"Package.swift","source":"Targets and dependencies"}],"sources":{"product.md":"From README","tech.md":"From Package.swift","structure.md":"From the source folders","principles.md":"From the tests and lint config"}}

- `product`: what the project is, for whom, and its main features.
- `tech`: languages, frameworks, platforms, build and test commands.
- `structure`: a `## Modules` list with one `- Name — path` line per module (the plain module name, no notes in parentheses), then other folders that matter.
- `principles`: the rules the code follows (style, testing, dependencies), as a list.
- `read`: the files and folders you read that shaped the context, each with what you took from it, at most 8.
- `sources`: for each of the four files, a few words on where its content came from ("From README", "Written from the name").
- Short and factual. Write only what you found or were told.
