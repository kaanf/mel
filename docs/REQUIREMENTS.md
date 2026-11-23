# Requirements

EARS acceptance criteria, same format Mel generates (see [SPEC-FORMAT.md](SPEC-FORMAT.md)). "THE APP" means Mel. Screens are named as in [UI.md](UI.md).

## 1. Detect the coding agent

As a user, I want the app to find the coding agent already on my Mac, so that I can start without configuring anything.

- 1.1 WHEN the app launches for the first time, THE APP SHALL show the Welcome window and scan for Claude Code (`claude`).
- 1.2 THE APP SHALL resolve executables using the user's login-shell `PATH` plus the configured extra search paths (defaults: `/opt/homebrew/bin`, `~/.local/bin`, `~/.npm-global/bin`), because apps opened from the Dock do not inherit the Terminal `PATH`.
- 1.3 WHILE a scan is running, THE APP SHALL show the agent row as "Checking".
- 1.4 WHEN an agent is found and authenticated, THE APP SHALL show its name, resolved path and "Ready".
- 1.5 WHEN an agent is found but not authenticated, THE APP SHALL show "Not signed in" and a "Sign In…" button.
- 1.6 WHEN the user clicks "Sign In…", THE APP SHALL open Terminal running Claude Code's own login command, and re-check the agent when the app becomes active again.
- 1.7 WHEN the user clicks "Scan Again" or "Scan Now", THE APP SHALL rerun detection.
- 1.8 WHEN Claude Code is not found, THE APP SHALL explain how to install it and offer "choose the file manually".
- 1.9 IF Claude Code is not Ready, THEN THE APP SHALL disable New Spec and say why, with a link to fix it.
- 1.10 WHERE "Look for the agent when the app opens" is on, THE APP SHALL rerun detection at every launch.

## 2. Manage the agent in Settings

As a user, I want to see how the app finds and uses Claude Code, so that I can fix problems.

- 2.1 THE APP SHALL show Claude Code in Settings › Agents with its status, version, location and account state.
- 2.2 WHEN the user clicks "Change…" for the location, THE APP SHALL let them choose an executable file and validate it before saving.
- 2.3 WHEN the user clicks "Open Terminal…", THE APP SHALL open Terminal with Claude Code's login command.
- 2.4 THE APP SHALL let the user add and remove extra search paths.

## 3. Start a new spec

As a user, I want to describe my idea in plain words, so that the agent can turn it into a spec with me.

- 3.1 WHEN the user chooses New Spec (⌘N, toolbar +, or sidebar), THE APP SHALL present the New Spec sheet.
- 3.2 THE APP SHALL require a name and an idea before Continue is enabled.
- 3.3 THE APP SHALL show which agent will write the spec ("Claude Code · Found on this Mac"), without a picker.
- 3.4 THE APP SHALL let the user choose the parent folder and show the resulting spec path (`<folder>/<slug>/specs`).
- 3.5 IF the target `specs` folder already contains any of the four files, THEN THE APP SHALL ask before using it and never overwrite those files silently.
- 3.6 WHEN the user clicks Continue, THE APP SHALL create the folder, save the idea, add the spec to the sidebar and start Discovery.

## 4. Discovery questions

As a user, I want to answer a few focused questions, so that the spec reflects what I actually want.

- 4.1 THE APP SHALL show one question at a time with its number ("Question 4"), which file it shapes, why it matters, and either 2–4 options plus "You decide" or, for an open question, a text field plus "Skip".
- 4.2 WHEN the agent marks an option as suggested, THE APP SHALL label it "Suggested" with the reason.
- 4.3 THE APP SHALL let the user pick an option with the mouse or the keys 1–4, and add an optional note for the agent.
- 4.4 WHEN the user presses Continue (↩), THE APP SHALL record the answer and request the next question.
- 4.5 WHEN the user picks "You decide", THE APP SHALL let the agent choose the best option for that topic and record it as an assumption.
- 4.6 THE APP SHALL show answered questions above the current one, and WHEN the user clicks one, THE APP SHALL let them change the answer.
- 4.7 THE APP SHALL show the coverage checklist in the inspector, grouped by phase (Product, Requirements, Design, Tasks), each topic "Covered", "Asking" or "Not yet", with a count ("3 of 7").
- 4.8 THE APP SHALL not limit the number of questions; Discovery SHALL end only WHEN every coverage topic is covered, and then start drafting PRODUCT.md.
- 4.9 WHEN the user clicks "Draft Now", THE APP SHALL end Discovery early and the agent SHALL decide the remaining topics as assumptions.
- 4.10 THE APP SHALL show the progress stepper (Idea › Questions › Draft › Review).
- 4.11 WHILE the app waits for the user's answer, THE APP SHALL show "Needs you" status in the toolbar and sidebar.
- 4.12 Discovery SHALL run in phases in file order: Product, Requirements, Design, Tasks. The agent SHALL finish a phase's topics before asking about the next phase, and MAY add a topic only to the current or a later phase.
- 4.13 WHEN a phase starts, the agent SHALL first ask an open question ("What do you have in mind for the design? Screens, style, apps you like…"); the user MAY answer in free text or skip. The agent SHALL then sharpen that answer with option questions.
- 4.14 WHERE the product has a user interface, the Design phase SHALL ask about the user experience: main screens and navigation, visual style and tone, and reference apps.

## 5. Draft a file

As a user, I want to watch the agent write each file, so that I know it is working and can stop it.

- 5.1 WHEN a stage starts, THE APP SHALL run the stage's agent with the approved earlier files and Discovery answers as context.
- 5.2 WHILE the agent is writing, THE APP SHALL show the status line ("Running · Writing criteria for story 3 of 5"), a progress bar and the step list (Done / Running / Next).
- 5.3 WHILE the agent is writing, THE APP SHALL show a live, read-only preview of the file as it grows, and state that editing becomes possible at review.
- 5.4 THE APP SHALL keep an Activity Log with timestamped agent actions, collapsed by default.
- 5.5 THE APP SHALL list the following files under "Up Next" with what each waits for.
- 5.6 WHEN the user clicks Stop, THE APP SHALL end the agent run, keep everything written so far, and offer "Continue Drafting" and "Review What's Written".
- 5.7 THE APP SHALL write the file to disk progressively, so that a crash or quit keeps the partial result.
- 5.8 WHEN a file finishes, THE APP SHALL move it to Review and post a notification if the app is not frontmost.
- 5.9 THE APP SHALL not start the next file until the previous file is approved.

## 6. Review and approve

As a user, I want to read, edit and approve each file, so that the spec says exactly what I mean.

- 6.1 THE APP SHALL show the file in a rendered Preview, and an editable raw Markdown view, switchable from the toolbar.
- 6.2 WHEN the user edits the file in the app, THE APP SHALL save it automatically and show "Saved · your edits are never overwritten"; WHEN the file changes in another editor, THE APP SHALL reload it, and IF the in-app editor has unsaved changes, THEN THE APP SHALL ask which version to keep.
- 6.3 THE APP SHALL show a "Before you approve" summary with the count of assumptions to confirm.
- 6.4 THE APP SHALL show each assumption with Confirm and "Change…".
- 6.5 THE generated files SHALL contain no open questions, TBDs or placeholders; WHEN drafting meets a gap Discovery didn't cover, the agent SHALL decide it and mark it as an assumption.
- 6.6 WHILE the file has unconfirmed assumptions, THE APP SHALL disable Approve and say how many remain; WHEN none remain and the user clicks Approve or presses ⌘↩, THE APP SHALL mark the file Approved.
- 6.7 WHEN a file is approved, THE APP SHALL unlock and start the next file.
- 6.8 IF the user edits an approved file, THEN THE APP SHALL mark it back to Review.
- 6.9 WHEN the user approves TASKS.md and a criterion is not covered by any task, THE APP SHALL warn before approving.

## 7. Recover from agent failure

As a user, I want a clear way forward when the agent stops, so that I never lose work or restart.

- 7.1 WHEN the agent process exits with an error or stops producing output past a timeout, THE APP SHALL mark the file "Stopped" and save the partial result.
- 7.2 THE APP SHALL explain the cause in plain words, distinguishing account limits (for example a usage limit) from spec problems, and state that approved files were not changed.
- 7.3 THE APP SHALL show per-file state (Approved, unchanged / Stopped at section N of M / Not started).
- 7.4 THE APP SHALL offer: resume, or finish the file by hand; WHEN a usage-limit reset time is known, THE APP SHALL post a notification at that time.
- 7.5 WHEN the agent resumes, THE APP SHALL give it the partial file and continue from the next unfinished section.
- 7.6 THE APP SHALL offer "Show Details" with the raw agent error output.

## 8. Hand off

As a user, I want to start building from the finished spec, so that the spec turns into software.

- 8.1 WHEN all four files are approved, THE APP SHALL show the Spec ready sheet with each file and its summary (for example "5 stories, 14 criteria").
- 8.2 THE APP SHALL show a Claude Code build command with Copy and "Open in Terminal" (in the project folder).
- 8.3 WHERE "Commit the spec to Git" is on, THE APP SHALL create one commit of `specs/` (always excluding `.mel/` (Mel's internal state; no setting in the MVP)), initializing a repository only after asking.
- 8.4 THE APP SHALL offer "Show in Finder".

## 9. Library and app shell

As a user, I want all my specs in one window, so that I can come back to any of them.

- 9.1 THE APP SHALL list specs in the sidebar, each expandable to Discovery and the four files with their states.
- 9.2 THE APP SHALL restore the library, selection and window state at relaunch.
- 9.3 IF a spec folder is moved or deleted outside the app, THEN THE APP SHALL show it as missing with "Locate…" and "Remove from list".
- 9.4 THE APP SHALL support standard macOS commands: ⌘N new spec, ⌘, settings, ⌘↩ approve, ⌥⌘I toggle inspector, ⌘⌫ remove from list.
- 9.5 THE APP SHALL support Light and Dark appearance and respect Reduce Motion and Increase Contrast.
- 9.6 THE APP SHALL run at most one agent at a time; WHILE one runs, starting another spec's run SHALL be disabled with the reason shown.
- 9.7 THE APP SHALL be distributed as a Developer ID–signed, notarized DMG.

## Later (not in the first version)

Designed on the canvas, deliberately left out of the first version to keep it small and fast:

- Pause / Resume of a running draft (Stop + Resume covers it).
- "Ask for changes" agent chat in Review, with inline Accept/Reject suggestions; Review inspector tabs Agent, Questions, History.
- Time estimates ("About 2 min left").
- Agent runs for several specs in parallel.
- Codex and choosing between agents.
