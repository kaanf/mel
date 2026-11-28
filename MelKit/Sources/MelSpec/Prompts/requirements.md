You are writing REQUIREMENTS.md, the user stories with WHEN … THEN … acceptance criteria, priorities, quality requirements and edge cases. The spec's files, in order: {{files}}.

You may read files in the current folder (Read, Glob, Grep), including the attachments listed below. Never write files; your reply is the file.

## Project context

{{project}}

## The work

Name: {{name}}

{{idea}}

## Attachments

{{attachments}}

## Intake answers

{{answers}}

## Decide and mark as assumption

{{decide}}

## Approved files

{{approved}}

## Steps

{{steps}}

## Format

```markdown
# Requirements

## 1. Book a class

P1 · MVP
Source: your idea, Question 4 (cancellations)

As a member, I want to book a class from the weekly schedule, so that my spot is guaranteed.

- 1.1 WHEN a member books a class with free spots, THEN one spot is reserved and one credit is deducted.
- 1.2 WHEN a class is full, THEN the app offers to join the waitlist instead.

<!-- MVP line -->

## 2. Gift cards

P2
Source: Question 2 (payments)

As a member, I want to buy a gift card, so that I can give classes to a friend.

- 2.1 WHEN a member completes payment, THEN the gift card is emailed to them.

## Quality requirements

Source: Intake (privacy, speed, offline) and project principles

- Q1 WHEN a member opens the weekly schedule on a mid-range phone, THEN it appears in under 1 second.
- Q2 WHEN the phone is offline, THEN the schedule shows the last loaded classes.

## Edge cases

- Two members book the last spot at the same moment: one gets it, the other is offered the waitlist.
```

- One `## <n>. <title>` section per story, numbered from 1, most important first.
- Under each heading: a tag line `P1 · MVP`, `P1`, `P2` or `P3`, then `Source:` naming where the story comes from (the idea, an intake question, the project context).
- Then one paragraph: "As a <role>, I want <goal>, so that <benefit>."
- Then its criteria as a list. IDs are `<story>.<criterion>`. Each is one sentence: `WHEN <the situation>, THEN <what must be true>.` The situation is something a user or a test can set up; the outcome is something a test can check. Task checks and tests are written from them. A criterion may wrap onto indented lines.
- Write `<!-- MVP line -->` on its own line once, after the last story tagged MVP.
- `## Quality requirements` lists `Q<n>` criteria, also WHEN … THEN …, for privacy, speed, offline and other qualities, with a `Source:` line.
- `## Edge cases` lists what happens in unusual situations, at least one for every P1 story.

{{rules}}
