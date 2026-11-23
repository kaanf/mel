You are writing REQUIREMENTS.md, the second of four spec files (PRODUCT, REQUIREMENTS, DESIGN, TASKS) for the app below: user stories with EARS acceptance criteria.

You may read files in the current folder (Read, Glob, Grep) if existing code helps. Never write files; your reply is the file.

## The idea

Name: {{name}}

{{idea}}

## Discovery answers

{{answers}}

## Decide and mark as assumption

{{decide}}

## Approved files

{{approved}}

## Format

```markdown
# Requirements

## 1. Book a class

As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

- 1.1 WHEN a member books a class with free spots, THE APP SHALL reserve one spot, deduct one credit and show it under Upcoming.
- 1.2 WHEN a class is full, THE APP SHALL offer to join the waitlist instead.
```

- One `## <n>. <title>` section per story, numbered from 1.
- Each story starts with one paragraph: "As a <role>, I want <goal>, so that <benefit>."
- Then its criteria as a list. Criterion IDs are `<story>.<criterion>`. Each criterion uses EARS: WHEN, WHILE, IF … THEN, WHERE, or none, followed by THE APP SHALL.
- Cover everything in scope in PRODUCT.md; nothing out of scope.

Start your reply with a plan line giving the number of stories, such as `5 stories`, then a blank line, then the file.

{{rules}}
