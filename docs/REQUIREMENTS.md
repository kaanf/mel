# Requirements

EARS acceptance criteria, the same format Mel generates (see [SPEC-FORMAT.md](SPEC-FORMAT.md)). "THE APP" means Mel. Screens are named as in [UI.md](UI.md) and `docs/design/v2/FLOW.md` › V2. Two product rules stand over all of them (OQ #24): the user can say, change or remove anything in their own words, and Mel never spends more tokens than doing the same spec by hand.

## 1. Find the coding agent

As a user, I want Mel to find the coding agent already on my Mac, so that I can start without configuring anything.

- 1.1 WHEN the app launches, THE APP SHALL look for Claude Code (`claude`) using the login shell's `PATH` plus the extra search paths, because apps opened from the Dock do not inherit the Terminal `PATH`.
- 1.2 THE APP SHALL show the agent on Start as one status line: found and signed in, checking, not signed in (with Sign In), or not working.
- 1.3 WHEN no agent is found, THE APP SHALL show the install command with Copy, Check Again and a link to choose the path, on the same screen.
- 1.4 WHEN the user clicks Sign In, THE APP SHALL open Terminal with Claude Code's own login command.
- 1.5 WHEN the window becomes active and the agent is not ready, THE APP SHALL look again.
- 1.6 WHILE the agent is not ready, THE APP SHALL keep Start disabled on Start and on New, and say why.
- 1.7 THE APP SHALL show the agent's status at the bottom of the sidebar; clicking it opens Settings › Agents.

## 2. Settings

As a user, I want the defaults in one place, so that Mel does not ask me the same things for every spec.

- 2.1 Settings › Agents SHALL show Claude Code's status, location and account state, let the user choose the executable, add and remove search paths, and scan again.
- 2.2 Settings › Specs SHALL hold: Show spec files in the sidebar (off), Open files in (the Mac's default app, or one that opens Markdown), Let Mel guess small details (on), Show token use on the board (on), Spec language, Write AGENTS.md (on) and Commit the spec to Git (on).
- 2.3 Settings › Specs SHALL show what Mel knows about the current project, with Show Files and Read Again, and the project's rules with Add Rule and a remove button per rule.
- 2.4 Settings › General SHALL show the version, "Check for Updates…" and "Automatically check for updates".

## 3. Start with a project

As a user, I want to point Mel at my code or at nothing, so that I can begin in one step.

- 3.1 WHEN the library has no project, or on first launch, THE APP SHALL show Start.
- 3.2 Start SHALL list the 5 most recently edited git repos in `~/Developer`, each with its folder, language and age, and "No code yet, start from an idea".
- 3.3 WHEN the user drops a folder on the window, THE APP SHALL add it to the list and select it.
- 3.4 WHEN the user presses Start with a repo, THE APP SHALL add it as the current project, open New, and read the project once in the background.
- 3.5 THE APP SHALL never make a screen wait for the project to be read; a spec's own runs go on next to it.
- 3.6 WHEN the user presses Start with "No code yet", THE APP SHALL open New without a project; the first spec then creates the project folder under `~/Developer`.
- 3.7 THE APP SHALL let the user switch projects, add one, locate a missing one and remove one from the sidebar's project menu.

## 4. Describe the work

As a user, I want one box to write in, so that I do not have to classify my own request.

- 4.1 New SHALL ask for the idea only. A Feature or Quick fix is named by the intake; WHEN the user starts a New product, THE APP SHALL ask its name once ("Let Mel name it" leaves it to the intake). A spec can be renamed from its sidebar menu.
- 4.2 WHEN the box has text, THE APP SHALL guess the size from the words, with no agent run: a bug is a Quick fix, a new app a New product, anything else a Feature; without a project it is always a New product.
- 4.3 THE APP SHALL show the guess as one chip with a one-line reason; WHEN the user clicks the chip, THE APP SHALL cycle Quick fix, Feature, New product and say "You picked …".
- 4.4 THE APP SHALL let the user add files with the attach button or by dropping them on the box, and copy them into the spec's folder.
- 4.5 WHEN the box is empty, THE APP SHALL offer three examples that fill it.
- 4.6 WHEN the user presses Start (⌘↩), THE APP SHALL create `specs/<slug>/` in the project, or a new project folder for a New product, select the spec and open its board.

## 5. Answer in one inbox

As a user, I want every question in one place and in one style, so that I always know what Mel needs from me.

- 5.1 WHEN a board opens for a new spec, THE APP SHALL run one intake that returns every question at once, and ask them one at a time under "Mel needs you".
- 5.2 Every question and card SHALL offer its options and "Something else…", which takes a typed answer used exactly like a tapped one.
- 5.3 WHEN the user clicks "Skip, write the plan now", THE APP SHALL start writing; the questions left become guesses.
- 5.4 WHEN a file is written, THE APP SHALL add its questions as cards: those the draft asked and one per open question it left in the file.
- 5.5 WHEN the check finds a contradiction, THE APP SHALL show it as a red "These disagree" card with its two fixes.
- 5.6 An answered card SHALL show its answer and Change.
- 5.7 WHEN every open card of the written files is answered, THE APP SHALL apply the answers in one change run (OQ #31).
- 5.8 Every answer the user gave SHALL be logged in DECISIONS.md with its reason.

## 6. Files written one at a time

As a user, I want Mel to write the files without me reading each one, so that I review a plan instead of documents.

- 6.1 THE APP SHALL write the size's files in order, one at a time, streaming each to disk as it grows.
- 6.2 THE APP SHALL start the next file only WHEN no card of the written files is open, so an answer never forces a later file to be rewritten.
- 6.3 WHILE a file waits for answers, THE APP SHALL say so in the toolbar pill and in Files ("ARCHITECTURE.md starts after 2 answers") and offer "Write it now".
- 6.4 WHEN the user clicks "Write it now", THE APP SHALL mark the open cards as guesses with no agent run and start the next file (OQ #32).
- 6.5 THE APP SHALL show four file states only: Ready, Writing, Needs you and Waiting.
- 6.6 THE APP SHALL show the plan from the files: stories in First version and Later, what it must also do, Screens (New product only) and Build order.
- 6.7 AFTER the last file of a Feature or New product, THE APP SHALL check coverage by ID itself and run one agent check for contradictions; "Check again" runs it on request (OQ #33).
- 6.8 WHEN everything is written, answered and applied, THE APP SHALL show "Plan is ready" and enable Start Building.
- 6.9 THE APP SHALL post a notification when the plan is ready, when Mel needs answers, and when the agent stops.

## 7. Change anything

As a user, I want to change, add or remove anything in my own words, so that the plan is mine.

- 7.1 THE APP SHALL show Tell Mel under the board's center once a file exists: one request at a time, with attachments, no chat and no history.
- 7.2 WHEN the user sends a request, THE APP SHALL run one change run that returns `{old, new}` edits and place them; every other passage stays word for word.
- 7.3 WHEN a change is placed, THE APP SHALL show one line ("Changed 2 places in REQUIREMENTS.md, 1 in TASKS.md") with its token cost and Undo, highlight the changed passages in an open file, and log the request in DECISIONS.md.
- 7.4 IF an edit cannot be placed, THEN THE APP SHALL change nothing and offer "Rewrite FILE" with its cost, and Cancel, which puts the request back in the box.
- 7.5 THE APP SHALL rewrite a whole file only from "Rewrite FILE".
- 7.6 WHEN the user moves a story between First version and Later, THE APP SHALL change its tag in REQUIREMENTS.md at once, with no agent run.
- 7.7 WHEN the user chooses Remove… on a story, THE APP SHALL list what goes with it (criteria, screens, tasks) before removing; Remove cuts the story and one change run takes out what was built on it, or nothing changes.
- 7.8 A removed story SHALL be listed in DECISIONS.md with Restore.
- 7.9 THE APP SHALL hide Tell Mel while it asks the intake questions, while the user edits a file and while the agent is stopped.

## 8. Read and edit files

As a user, I want the Markdown files one click away, so that I can check or change them myself.

- 8.1 WHEN the user clicks Files, THE APP SHALL list the files with their states; clicking one opens it in the board's center (⌘1 to ⌘5; Esc goes back to the plan).
- 8.2 An open file SHALL offer Formatted and Markdown views, Open in Editor, Reveal in Finder and Edit.
- 8.3 A file still being written SHALL be read-only, a file not started cannot be opened, and DECISIONS.md is read-only.
- 8.4 WHEN the user saves an edit, in Mel or in another editor, THE APP SHALL keep it and show a banner naming the files built on it, with Update, "Keep them as they are", "Undo my change" and a "Why?" field saved to DECISIONS.md.
- 8.5 Update SHALL run one change run that changes only what depends on the edit.
- 8.6 IF a file changes on disk while the in-app editor has unsaved text, THEN THE APP SHALL ask which version to keep, and never overwrite either silently.
- 8.7 WHERE "Show spec files in the sidebar" is on, THE APP SHALL list the open spec's files under it.

## 9. When the agent stops

As a user, I want a clear way forward when the agent stops, so that I never lose work.

- 9.1 WHEN a run fails, times out or is stopped, THE APP SHALL keep everything written, show a banner with the cause in plain words, and run nothing until the user resumes.
- 9.2 The banner SHALL offer Resume and, when a file was cut off, "Finish it myself", which opens that file for editing.
- 9.3 WHEN the user resumes a cut-off file, THE APP SHALL continue it from its last complete section in the same Claude Code session, or write it again if that session is gone.
- 9.4 WHEN a usage limit has a known reset time, Resume SHALL wait for it and post a notification then.
- 9.5 A board that was working when Mel quit SHALL wait for Resume at the next launch.
- 9.6 THE APP SHALL run one spec at a time; starting a second SHALL be refused with the reason.

## 10. Token use

As a user, I want to see what a spec costs me, so that I can trust Mel with my plan's usage.

- 10.1 THE APP SHALL count each run's output and uncached input tokens from `result.usage` and keep them per spec and step (OQ #26).
- 10.2 WHERE "Show token use on the board" is on, THE APP SHALL show the spec's total in the board toolbar, with a popover by step, and state it on Ready.
- 10.3 THE APP SHALL never start an agent run for a scope move, for "Write it now", for Mel's own coverage checks or for finding what a removed story takes with it.

## 11. Hand off

As a user, I want one button that starts the build, so that the plan turns into software.

- 11.1 WHEN the user clicks Start Building, THE APP SHALL write `prompts/task-NN.md` for each task, and as Settings › Specs says, write AGENTS.md (only its own marked block) and commit the spec to Git (never `.mel/` state).
- 11.2 Ready SHALL state what was planned (stories, tasks, token use) and offer "Build with Claude Code" (⌘↩), which opens Terminal in the project with task 1's prompt.
- 11.3 Ready SHALL offer each task's prompt with Copy Prompt and its check command, and the spec files, both closed by default.
- 11.4 WHEN the user starts the build, THE APP SHALL list the spec under Building; WHEN the user marks it done, under Done (OQ #34).

## 12. Library and app shell

- 12.1 THE APP SHALL list the current project's specs in the sidebar as Needs you, Building and Done, each with one line on what it waits for or what Mel is doing.
- 12.2 THE APP SHALL restore the library and the current project at relaunch, and find specs by scanning `specs/*/.mel/state.json`.
- 12.3 IF a project folder is moved or deleted outside the app, THEN THE APP SHALL offer "Locate…" and "Remove from the List" in the project menu.
- 12.4 A spec made before 0.5 that was drafting, in review, stopped or in Analyze SHALL open on the board with its files and open questions.
- 12.5 THE APP SHALL support ⌘N New, ⌘, Settings, ⌘↩ for the screen's primary action and ↑/↓ in the sidebar.
- 12.6 THE APP SHALL follow the system's Light or Dark appearance and respect Reduce Motion.
- 12.7 THE APP SHALL be distributed as a Developer ID signed, notarized DMG and update itself (Check for Updates…, daily check unless turned off).

## Invariants

- Mel is the only writer of the spec files. Claude Code runs without write or shell tools.
- Never overwrite a user's edit. Never change a Ready file without a user action: a card answer, Tell Mel, Remove, Update or Rewrite (OQ #29).
- All file writes are atomic.

## Later (drawn on the canvas, not built)

- Codex and choosing between agents (Start, Ready, the stopped banner, Settings › Default agent).
- "Ask me before an agent changes the plan", and Mel following the coding agent's progress ("Task 3 of 7", "Merged yesterday").
- "Save specs to" as a setting; Settings › Advanced.
- Time estimates.
