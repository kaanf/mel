# Mel screen flow

Read this file first. It maps every screen file in this folder to its place in the app, what it is for, and where each button leads.

## How to read a screen file

- Each `*.dc.html` file is one screen of the native macOS app, drawn as an HTML mockup. Build it in SwiftUI; do not ship the HTML.
- The top of every file has a `MEL SCREEN` comment with the screen id, purpose, entry points and exits. It matches the table below.
- Markup inside `<x-dc>` is the layout. `{{name}}` holes are filled by `renderVals()` in the `<script>` at the bottom. That script holds sample data and UI state; treat it as the view model's shape, not real logic.
- An `href="Native-....dc.html"` is a navigation edge to that screen. `href="#"` means "not wired in the mockup".
- Sample content (Yoga Studio Booking, yoga-studio-booking repo) is placeholder data.
- `Mel-Logo.dc.html` is the app icon and its usage, not a screen.

## V2 · Simplified flow (proposal)

Status: **chosen** (2026-11-26), drawn in the two bottom rows of the canvas. Build the V2 screens instead of lanes A, B and C; Native-Settings-Agents.dc.html stays as Settings › Agents. Everything from "## Lanes" down describes the earlier lanes and D1: reference only. Where it differs from this V2 section (background drafting, file states, sidebar), V2 wins.

Goal: before the agent starts, the user makes at most 2 decisions (write, press Start). The Markdown files still exist and are still written in the same order; the user reviews a plan and answers questions, and opens files only if they want to.

| Id | File | Screen | Replaces |
|---|---|---|---|
| V2-0 | V2-0-Start.dc.html | Start: agents found as one status line, pick a repo or start from an idea, Start | A1, A1x, A2, A3, A4x |
| V2-0b | V2-0b-NoAgent.dc.html | Start with no agent found (state of V2-0, prop agentsFound = false) | A1x |
| V2-1 | V2-1-New.dc.html | New: one text box. Mel guesses the size and shows it as one chip the user can change. Also the home screen when a project has no specs | B1, C3 |
| V2-2 | V2-2-Board.dc.html | Board: questions, decision cards, plan, files, edit banner, stopped banner | B2, D1, C1, C2 (and the B3 to B6 references) |
| V2-4 | V2-4-Board-File.dc.html | Board with a file open and a Tell Mel change just applied, changed passage highlighted (state of V2-2, props openFile, tell = "result") | file review in B4, B5 |
| V2-5 | V2-5-Board-Stopped.dc.html | Board, agent stopped, files pinned in the sidebar (state of V2-2, props scenario = "stopped", sidebarFiles = true) | C2 |
| V2-7 | V2-7-Board-Unplaced.dc.html | Board, a Tell Mel change couldn't be placed: Rewrite ARCHITECTURE.md or Cancel (state of V2-2, prop tell = "unplaced") | new |
| V2-8 | V2-8-Board-Remove.dc.html | Board, Remove confirmation on a story card (state of V2-2, prop confirmRemove = "pack") | new |
| V2-9 | V2-9-Board-Waiting.dc.html | Board, files waiting for answers, Files list and token popover open (state of V2-2, props start = "plan", filesOpen, tokensOpen) | new |
| V2-10 | V2-10-Board-Plan.dc.html | Board, plan ready: every card answered, all files written; where Build › Plan returns (state of V2-2, prop start = "ready") | new |
| V2-11 | V2-11-Build-Typing.dc.html | Build, typing a Tell Mel request with a task chip (state of V2-3, prop tell = "typing") | new |
| V2-12 | V2-12-Build-Working.dc.html | Build, Mel changing files: working line, Check it disabled on changed tasks (tell = "working") | new |
| V2-13 | V2-13-Build-Changed.dc.html | Build, change applied: result line, Updated tags, Prompt changed, Changed after done, new task (tell = "result") | new |
| V2-14 | V2-14-Build-Unplaced.dc.html | Build, change couldn't be placed (tell = "unplaced") | new |
| V2-15 | V2-15-Board-Roadmap.dc.html | Board, Roadmap tab: phases → tasks → covered criteria, every item shown (state of V2-2, props start = "ready", tab = "roadmap") | Build order tab |
| V2-16 | V2-16-Board-Flow.dc.html | Board, Flow tab: each flow as screen cards with states and criteria, branches below, missing states red (state of V2-2, props start = "ready", tab = "flow") | Screens tab |
| V2-17 | V2-17-Build-Run.dc.html | Build, Mel runs the tasks itself (proposal): Run instead of Copy prompt, Run the rest in the toolbar, the spec branch, one task at a time, tasks that can't run yet disabled with the reason, plain-language progress, Stop (prop scene = "running") | new |
| V2-18 | V2-18-Build-Question.dc.html | Build, Claude Code stops for a question that changes what users see; the card in Mel's column with what each option means (scene = "question") | new |
| V2-19 | V2-19-Build-Report.dc.html | Build, a task done: What works now, Decided while building (Change… → Tell Mel), Not done, check and commit (scene = "report") | new |
| V2-20 | V2-20-Build-Dirty.dc.html | Build, Run refused over changes that aren't committed: Commit them / Put them aside, then run / Cancel (scene = "dirty") | new |
| V2-21 | V2-21-Build-Stopped.dc.html | Build, a task stopped: its changes are uncommitted, Keep them (Run again goes on) / Undo them (scene = "stopped") | new |
| V2-22 | V2-22-Build-Built.dc.html | Build, every task done on mel/<slug>: Merge into main / Open a pull request (scene = "built") | new |
| V2-23 | V2-23-Build-Conflict.dc.html | Build, merge into main conflicts: the files, Let Claude Code resolve it / Open in Terminal / Cancel; nothing merged (scene = "conflict") | new |
| GH-1 | GH-1-Start-GitHub.dc.html | Start with GitHub (OQ #44): a GitHub line under Your agent (account, Sign in to GitHub…), On this Mac / On GitHub tabs, Clone and Start for a repo not on this Mac (prop gh = "signedIn" / "signedOut" / "signingIn" / "missing") | V2-0 |
| GH-1b | GH-1b-Start-SignIn.dc.html | Start, signing in: the one-time code from `gh auth login --web` (gh = "signingIn") | new |
| GH-1c | GH-1c-Start-NoCLI.dc.html | Start, no GitHub CLI: `brew install gh`, Check Again; GitHub optional (gh = "missing") | new |
| GH-2 | GH-2-Repo-Sheet.dc.html | A New product's name sheet asks where its code lives: a new GitHub repo (owner, name, Private / Public), a repo you already made (clone), only on this Mac (prop mode = "new") | name sheet |
| GH-3 | GH-3-Project-Connect.dc.html | Connect a project on this Mac to GitHub, from the project menu: new repo or an empty one you made; one with its own history is refused (mode = "connect") | new |
| GH-4 | GH-4-Build-PR.dc.html | Build, every task done, with GitHub: each task checked and pushed, one pull request per spec, GitHub's checks in Mel's column, Merge pull request / Merge when checks pass / a failed check with Let Claude Code fix it (prop pr = "checks" / "ready" / "failed" / "merged") | V2-22 when there is a GitHub repo |
| GH-5 | GH-5-Build-Merged.dc.html | Build, merged on GitHub: squashed, branch deleted, this Mac on an up-to-date main (pr = "merged") | new |
| V2-3 | V2-3-Ready.dc.html | Build: tasks in steps (run alone, at the same time, one after the other), Copy prompt, Check it, Done; back to the plan | B7 |
| V2-6 | V2-6-Settings-Specs.dc.html | Settings › Specs: the defaults V2 stopped asking about | B1 fields, B7 toggles, A3 rules |

V2-0b, V2-4, V2-5, V2-7, V2-8, V2-9, V2-10, V2-11 to V2-14, V2-15 and V2-16 are the same components as V2-0, V2-2 and V2-3 with different props: build them as states, not screens.

Main path:

```
V2-0 Start ──Continue──▶ V2-1 New ──Plan it──▶ V2-2 Board ──Start Building──▶ V2-3 Build ──Plan (steps)──▶ V2-10 Board, plan ready
```

Rules that change from V1:

- **Size is inferred.** The agent classifies the request as Quick fix, Feature or New product from the text and the repo. One chip shows the guess; clicking it cycles the sizes. Files per size are unchanged (see "Spec files and their order").
- **Project context is read in the background** after Start on V2-0, once per repo. No screen waits for it. Its files and the rules (principles.md) are in Settings › Specs.
- **One inbox ("Mel needs you").** Before the draft: up to 3 intake questions, one at a time, with "Skip, write the plan now" (skipped ones become guesses). After each file: its decision cards, all in one style. Every question and card also offers "Something else…" for a free answer. Only a real contradiction gets the red "These disagree" card. No Conflict / Gap / Missing / Assumption labels.
- **4 file states only:** Ready (green dot), Writing (blue ring), Needs you (blue dot), Waiting (grey ring, not started yet). Stopped and out-of-date files show as Needs you, with the reason in the banner.
- **Files:** the Files button in the board toolbar lists the files. Clicking one opens it in the board's center: Formatted or Markdown, Open in Editor (Settings › Specs › Open files in), Reveal in Finder, Edit. A file still being written is read-only. DECISIONS.md is read-only (decisions change from their cards). Keyboard: ⌘1 to ⌘5 open the files in order, Esc returns to the plan. Settings › Specs › "Show spec files in the sidebar" (off by default) also lists them under the open spec.
- **Edit after it's written** (was C1): saving an edit shows a banner in the board with the files built on it, Update / Keep them as they are / Undo, and a "Why?" field saved to DECISIONS.md.
- **Agent stopped** (was C2): a banner in the board: Resume when the limit resets (on its own, with a notification), or Finish it myself (opens the file). Answers and finished files are untouched.
- **Plan tabs:** Plan, Flow, Roadmap. Flow appears only for New product (it needs EXPERIENCE.md). Flow (V2-16, replaces Screens) shows every flow in EXPERIENCE.md as a row of screen cards: the screen's name, its states (a state marked `!` is missing and shows red) and the criteria it covers, with the flow's branches below. A card opens EXPERIENCE.md. Mel builds it in Swift, no agent run. Roadmap (V2-15, replaces Build order) shows the whole plan: phases from the `##` headings in TASKS.md, each phase's tasks with priority and check, and under each task the criteria it covers (from `Covers`, text from REQUIREMENTS.md). Every item is shown; Mel builds it in Swift, no agent run. Without phase headings it groups by priority. Later stories without tasks are listed below the phases.
- **Build** (V2-3, was Ready / B7): until Mel runs agents itself, the user runs each task's prompt in their own Claude Code. Tasks are grouped in steps from TASKS.md: Run alone, At the same time (only when the tasks change different folders; open one terminal each), One after the other (same folder). A step opens when the step before it is done. Each task: Copy prompt (short, names only the passages it needs, marks the task Running), Check it (Mel runs the task's verify command on this Mac: no agent, no tokens), passed → Done and the next tasks open, failed → the output, Copy fix prompt (includes the error), Check again. "Mark done without the check" and Reopen are always there. Plan in the steps control goes to V2-10. When all tasks are done the spec moves to Done. Tell Mel is on Build too, pinned at the bottom of the right column: Running and Failed cards have "Tell Mel about this", which adds a task chip (and the check output from a failed card) so the request knows where it came from. While Mel changes files, Check it is disabled only on the tasks being changed. After a change, a running task whose prompt changed shows "Prompt changed · Copy again", a done task whose text changed shows "Changed after done" with Reopen (Mel never reopens it on its own), and a new task appears in its step with a soft highlight. The working line (file · where · Stop) is shared with the board. When Mel runs agents later, Copy prompt becomes Run and Check it runs on its own; steps and checks stay. AGENTS.md, commit and "ask before an agent changes the plan" are on by default and live in Settings › Specs.

## V2 · Expressiveness and token budget

Users could write these files by hand in Claude, ChatGPT or Claude Code, so V2 holds two rules at once:

1. **Expressiveness.** The user can say anything in their own words, and change or remove anything easily, at any point.
2. **Token budget.** Mel never spends more tokens than doing it by hand, and less where it can. Tokens go on rewriting files, not on the user talking. Every change is a small patch to the affected passages; a file is never rewritten from scratch unless the user explicitly chooses it.

Rules that follow from them (all on V2-2 Board):

- **Tell Mel.** (Now a bar plus the Tell Mel panel: see "V2 · Tell Mel panel and questions".) One free-text field at the bottom of Mel's column (the right column), also when a file is open: "Tell Mel what to change, add or remove…". Long text and attachments are fine. One request at a time against the current files; there is no chat and no history. Mel finds the passages the request touches and patches only those.
  - Result: one line, for example "Changed 2 places in REQUIREMENTS.md, 1 in ARCHITECTURE.md, 1 task in TASKS.md", with Undo. Changed passages are highlighted in the open file until the line is dismissed. (V2-4)
  - The change and its reason (the user's own words) are added to DECISIONS.md automatically.
  - Can't be placed: "Mel couldn't find where this goes in ARCHITECTURE.md." with Rewrite ARCHITECTURE.md (shows its cost) and Cancel. A whole-file rewrite only ever happens from this button, so it is always the user's explicit choice. Cancel puts the request back in the box. (V2-7)
  - Hidden while asking intake questions (there are no files yet), while editing a file by hand and while the agent is stopped.
- **Free answers.** Every intake question and decision card has "Something else…" next to its one-tap answers. It opens an inline text field; the typed answer is used exactly like a tapped one. An answered card shows the answer and Change.
- **Removing.** Each story card in Plan has a ··· menu with Remove…. A confirmation in the card lists what goes with it, for example "Also removes requirement 2.1, 2 screens in EXPERIENCE.md, the payments module in ARCHITECTURE.md and task 3", with Remove and Cancel (V2-8). Removing patches those passages out. Removed stories are logged in DECISIONS.md with Restore.
- **Scope moves are free.** Story cards drag between "First version" and "Later" (the Later / First buttons and the ··· menu do the same). It changes at once: no agent run and no progress indicator, because only the priority marker of that story changes.
- **Files are written one at a time, gated.** The next file starts only when the cards of the files before it are answered, so an answer never forces a rewrite of a later file. The waiting file reads "ARCHITECTURE.md starts after 2 answers" in Files and in Mel's status line. A quiet "Write it now" link writes on without waiting; unanswered cards then become guesses, the same rule as "Skip, write the plan now". Not-started files are Waiting (grey ring) and can't be opened yet. (V2-9)
- **Token use is visible.** The board toolbar shows a small, neutral total for this spec, for example "41k tokens". Clicking it opens a popover by step: project context, questions, each file, checks, changes (V2-9). Settings › Specs › "Show token use on the board" (on by default) hides it. V2-3 Ready states the total in its summary.

## V2 · One whole

Added 2026-11-27 after a UX review against current agent and macOS patterns. Each screen should feel like a step of one
journey, so the same few pieces repeat everywhere and nothing new costs tokens:

- **Steps control: Idea › Plan › Build.** One segmented control in the toolbar of New (Idea current), the board (Plan) and
  Build (Build). Done steps show a check, the current one is raised, later ones are grey until they open: Build opens when
  the plan is ready, Plan on Build returns to V2-10. It replaces the separate ‹ Plan breadcrumb and tells the user where
  they are and what comes next without a tutorial. Buttons follow the same words: Continue (Start), Plan it (New), Start
  Building (board).
- **Mel's column.** The right column is Mel's on the board and on Build: a title ("Mel needs you · 2", "Nothing needs
  you"), Mel's status line (what it is doing or waiting for, with Write it now; this is the old toolbar pill), then the
  questions and cards (board) or how building works (Build), and the Tell Mel box pinned at the bottom. The user looks in
  one place for "what does Mel want" and "tell Mel something". The center is always the user's work: plan, file or steps.
- **One composer.** New and both Tell Mel boxes are the same: text, Attach, Dictate (macOS speech to text into the box,
  read before sending), the primary button. Saying an idea out loud is the lowest-effort way to start.
- **One result line with Undo.** Every change shows one line in Mel's column right above the box: a Tell Mel change, a
  rewrite, and now Remove ("Removed “Buy a class pack” and what was built on it" · Undo). Restore in DECISIONS.md stays
  for later.
- **Honest defaults.** The likely answer on a question is marked "Likely · ↩" (Return picks it). Skip says what happens:
  the Likely answer is used, or a guess, and each one is listed under "small things Mel guessed".
- **Leave while Mel works.** New says it up front ("Mel writes the plan · leave, you get a notification"), and the board
  repeats it while a file is being written or the agent is stopped. Mel already notifies when it needs the user.
- **What happens next, once.** Under New's box: Up to 3 questions · Mel writes the plan · You build it.
- **Only what ships.** Claude Code only (no Codex on Start or the stopped banner); Settings › Specs shows only the settings
  the app has.

Sources for this review: setproduct.com "16 AI agent UI design patterns", beyondchat.design and agentic-ux.com
"Clarifying questions", Jakob Nielsen "Slow AI" and "Think-time UX", Smashing Magazine "Practical interface patterns for
AI transparency" (2026), Apple HIG Sidebars and Toolbars, WWDC25 "Get to know the new design system".

## V2 · Tell Mel panel and questions (chosen, in V2-2)

Added 2026-11-28 and moved into V2-2-Board.dc.html the same day, so every board state (V2-4, V2-5, V2-7 to V2-10, V2-15,
V2-16) has them. V2-24 to V2-29 are states of V2-2. Where this section differs from "V2 · Expressiveness" (the Tell Mel box
at the bottom of the column, the one-line result), this section wins. REQUIREMENTS.md in V2-2 also shows WHEN/THEN criteria.

- **Mel's column is 380 px** (was 300), 20 px padding. Prop melWidth on V2-24 tries 340 / 380 / 420.
- **Tell Mel panel.** The column keeps a one-line "Tell Mel…" bar (⌘K) and the last result line. Writing happens in a 680 px
  panel over the board: Where chips (Let Mel decide or one file), a large field, attachments as file cards, three starters,
  Attach, Dictate, the cost hint, Send to Mel (⌘↩). Working shows the request and 4 live steps with Stop. Review shows every
  change by file as before/after lines with Undo this, Undo all and Done; the changes are already applied, so closing keeps
  them. Couldn't be placed shows two choice cards: Rewrite the file (its cost) or Say it differently.
- **Questions.** The intake question is one card: a 3-step bar, the question, numbered answer rows (1 to 3, the likely one
  marked Likely ↩), Something else…; answered questions stack above it with Change. Decision cards are grouped by file under
  a progress bar. Only the next open card is expanded, the others are one-line rows; answering opens the next. A
  contradiction shows its two sources as tiles (the value and where it comes from).

| Id | File | Screen |
|---|---|---|
| V2-24 | V2-24-Tell-Compose.dc.html | Board with the Tell Mel panel open, writing (state of V2-2, tellPanel = "compose") |
| V2-25 | V2-25-Tell-Working.dc.html | Tell Mel panel, working: live steps, Stop (tellPanel = "working") |
| V2-26 | V2-26-Tell-Review.dc.html | Tell Mel panel, review what changed (tellPanel = "review") |
| V2-27 | V2-27-Tell-Unplaced.dc.html | Tell Mel panel, couldn't be placed (tellPanel = "unplaced") |
| V2-28 | V2-28-Questions-Intake.dc.html | Intake question, redesigned (start = "intake2") |
| V2-29 | V2-29-Questions-Cards.dc.html | Decision cards, redesigned (start = "cards") |

## V2 · Spec upgrades from the competitor review

Added 2026-11-28 after comparing Mel with Kiro, GitHub Spec Kit, OpenSpec, Traycer, Devin, Factory and BMAD. All eight are
chosen. Drawn in the row "V2 · Spec upgrades".

| Id | File | Screen |
|---|---|---|
| V2-30 | V2-30-New-Split.dc.html | New, an idea with two goals: the split suggestion (state of V2-1, prop idea) |
| V2-31 | V2-31-Board-Today.dc.html | Board, REQUIREMENTS.md in WHEN/THEN with delta tags, the "Changes how it works today" card (component of V2-31 to V2-35, scene = "today") |
| V2-32 | V2-32-Board-BugFix.dc.html | Board, a bug fix SPEC.md: now, should, must not change, check (scene = "bugfix") |
| V2-33 | V2-33-Board-Diagram.dc.html | Board, ARCHITECTURE.md with its mermaid diagram drawn (scene = "diagram") |
| V2-34 | V2-34-Build-ProjectSpec.dc.html | Build, every task done: update the project spec, then merge (scene = "merge") |
| V2-35 | V2-35-Plan-Export.dc.html | Plan ready, Send tasks to GitHub Issues or Linear (scene = "export") |

1. **The project spec: how the app works today.** `specs/current/` holds one Markdown file per area of the app (schedule.md,
   payments.md, teachers.md…). Every requirement in it has a stable id (B-2.1). It is the truth about the app as it is; the
   spec folders describe changes.
   - The project context scan writes the first version from the code (one file per area, only behavior a user can see).
   - While a spec is written, Mel reads the areas it touches. Each criterion in REQUIREMENTS.md (or SPEC.md) gets a delta tag:
     Adds, Changes B-x.y, Removes B-x.y, Keeps B-x.y. A criterion that contradicts today's rule raises the card
     **"Changes how it works today"**: today's value and id next to this spec's value, as two tiles, plus Something else…
     (V2-31). It is not the red "These disagree" card: nothing is wrong, the user decides whether the app changes.
   - When every task is done, Build shows **"Update how the app works today"** before Merge into main: the deltas by file
     (Changed with before and after, Added, a New file badge), then Update the project spec / Not now (V2-34). Mel merges by
     id in Swift: no agent run, no tokens. The spec folder moves to `specs/done/<date>-<slug>/`. "Not now" leaves it under
     Done with the same button. The result line has Undo.
   - Settings › Specs shows "How the app works today" with Show Files.
2. **Criteria as WHEN … THEN ….** Every acceptance criterion and quality rule is written as WHEN (the situation) THEN (what
   must be true), with its id. The Formatted view shows WHEN and THEN as small labels; Markdown keeps the plain sentence.
   Task checks and, later, generated tests are written from these. Settings › Specs › "Write criteria as When / Then" (on).
3. **Bug fixes.** When a Quick fix is a bug, SPEC.md has four parts: What happens now (steps to reproduce), What should happen
   (WHEN/THEN, tagged Fixes B-x.y), **Must not change** (the project spec rules the fix must keep, each with its id, shown
   with a lock) and Check (the command that proves it) (V2-32). Questions can add rules to Must not change.
4. **Split suggestion.** On New, when the text reads like two separate features (two actors or two goals joined by "and"), a
   card under the box proposes 2 specs with names and sizes: Split into 2 specs / Keep as one (V2-30). Split plans the first
   now; the second waits under Needs you with the user's words. Settings › Specs › "Suggest splitting big requests" (on).
5. **Technical change (design first).** A fourth size for refactors, migrations, upgrades and performance work. Files, in
   order: ARCHITECTURE.md, REQUIREMENTS.md (derived from it), TASKS.md, then Analyze. The size chip on New cycles Quick fix,
   Feature, Technical change, New product.
6. **Diagrams.** A ```mermaid block in any spec file (mostly ARCHITECTURE.md) is drawn in the Formatted view, with what this
   spec changes in blue and what it adds in green; Markdown shows the code (V2-33). Drawn in Swift, no agent run.
7. **Send tasks.** Plan ready and Build have "Send tasks…" in the toolbar: GitHub Issues (uses `gh` on this Mac, signed in) or
   Linear (key asked the first time). One issue per task; options: criteria as a checklist, phases as milestones (cycles in
   Linear); label `mel · <slug>`. Tasks already sent are skipped; issue numbers are saved in TASKS.md (V2-35). No tokens.
8. **Models for each step.** Settings › Agents › "Models for each step": Questions and decision cards, PRODUCT / REQUIREMENTS /
   EXPERIENCE, ARCHITECTURE.md, TASKS.md, Analyze and checks, Tell Mel changes. Defaults: Opus for the product files and
   ARCHITECTURE, Sonnet for the rest. Claude Code runs each step with `--model`.

Not taken, on purpose: separate planning personas (BMAD; multiplies tokens, breaks the token budget rule), a chat about the
code (Ask Devin; Mel has no chat by design), comparing code against the spec after building (Spec Kit converge, Traycer
verify; belongs to the Build stage, revisit with V2-17).

Sources: kiro.dev docs (Specs, Bugfix Specs, Analyze Requirements, Correctness), github.github.com/spec-kit (Agentic SDD
reference), OpenSpec concepts (Fission-AI/OpenSpec), docs.traycer.ai (Phases), docs.factory.ai (Specification Mode), Devin
docs (Interactive Planning, Ask Devin), BMAD Method user guide.

## Lanes (reference, replaced by V2)

- **A · First run**: from first launch to a project Mel has read.
- **B · Write a spec**: the main loop, from a new spec to handoff.
- **C · Other states**: screens reached from conditions, not from a single button.
- **Reference** (bottom row on the canvas): B3, B4, B5 and B6. Replaced by D1 Spec board. Keep them only to understand what D1 summarizes; do not build them as separate screens.

## Screens

| Id | File | Screen | Purpose |
|---|---|---|---|
| A1 | Native-0-Welcome.dc.html | Welcome | First launch. Shows the coding agents found on this Mac. |
| A1x | Native-E1-NoAgents.dc.html | Welcome, no agent | Same moment when no Claude Code or Codex is found. Install commands, Check Again. |
| A2 | Native-E2-PickFolder.dc.html | Pick a project | Choose a repo folder, pick one Mel found, or start from an idea with no code. |
| A3 | Native-0b-ProjectSetup.dc.html | Project context | Mel reads the repo once and writes product.md, tech.md, structure.md, principles.md to `.mel/project/`. |
| A4x | Native-E4-FirstSpec.dc.html | First spec, no project | New Spec when the user has no project yet. Only Product size is available. |
| B1 | Native-1-NewSpec.dc.html | New Spec | Pick size (Quick fix, Feature, Product), project, and describe the work. Input changes per size. |
| B2 | Native-2-Discovery.dc.html | Intake | The agent asks a few questions. Coverage list on the right. A second round comes after the draft. |
| B3 | Native-2b-Drafting.dc.html | Drafting (reference) | Live progress while the agent writes a file. Stop and resume. |
| B4 | Native-3-Review.dc.html | Review a file (reference) | Review REQUIREMENTS.md: priorities, MVP line, quality requirements, edge cases, assumptions, open questions. The same layout reviews PRODUCT.md, ARCHITECTURE.md and TASKS.md. |
| B5 | Native-3b-Experience.dc.html | Review EXPERIENCE.md (reference) | Flows, screens and their states, visual direction. Missing states are flagged. |
| B6 | Native-3c-Analyze.dc.html | Analyze (reference) | Cross-file check before handoff: coverage matrix and issues (contradiction, no task, quality not covered, scope creep). |
| B7 | Native-4-Done.dc.html | Spec ready | Handoff: per-task prompts with verify commands, AGENTS.md, keep-in-sync, commit. |
| C1 | Native-3d-Refine.dc.html | Refine after edit | User changed a finished file or an answered decision. Downstream files are marked out of date; the reason is saved as a decision. |
| C2 | Native-Error-Partial.dc.html | Agent stopped | The agent stopped mid-file (for example a usage limit). Decisions and finished files are untouched; choose how to continue. |
| C3 | Native-E3-Home.dc.html | Home, no specs | Main window with no specs yet. Shown on reopen or after cancelling New Spec. |
| C4 | Native-Settings-Agents.dc.html | Settings › Agents | Choose and configure the coding agents. |
| D1 | Native-D1-SpecBoard.dc.html | Spec board (main loop) | One screen instead of B4, B5 and B6. Decision inbox (conflicts, gaps, assumptions answered with one tap), Scope / Flow / Plan tabs, one verdict, Start Building. The Markdown files still exist; the user reviews decisions, not documents. |



## Main path (reference, replaced by V2)

```
A1 Welcome ──Continue──▶ A2 Pick a project ──Read This Repo──▶ A3 Project context ──Save and Start a Spec──▶ B1 New Spec
A1x No agent ──Check Again──▶ A1      A2 ──Start from an Idea──▶ A4x First spec ──Start──▶ B2

B1 New Spec ──Start──▶ B2 Intake ──Continue / Draft Now──▶ D1 Spec board ──Start Building──▶ B7 Spec ready

On D1 the agent drafts PRODUCT, REQUIREMENTS, EXPERIENCE, ARCHITECTURE and TASKS in the background (status pill = old B3).
Decision cards replace file-by-file review (old B4, B5). The verdict and conflict cards replace the separate Analyze screen (old B6).
```

## Conditional screens (reference, replaced by V2)

- **C1** opens when the user edits a finished file or changes an answered decision. Exit: Refine (back to D1; the agent updates the affected parts and raises cards if needed) or Keep Them as They Are.
- **C2** opens when the agent stops before a file is finished. Exit: resume later on D1, continue with the other agent, or finish the partial file by hand from the sidebar.
- **C3** is the main window when the selected project has zero specs.
- **C4** opens from A1x (Choose path…) and from the app menu.

## Spec files and their order

Feature, Technical change and Quick fix specs live in the chosen repo under `specs/<spec-name>/`. Product specs get a new folder. `specs/current/` is the project spec (how the app works today, one file per area, ids like B-2.1); a built spec moves to `specs/done/<date>-<slug>/` after its deltas are merged.

| Size | Files, in order |
|---|---|
| Quick fix | SPEC.md (a bug: What happens now, What should happen, Must not change, Check) |
| Feature | REQUIREMENTS.md, ARCHITECTURE.md, TASKS.md, then Analyze |
| Technical change | ARCHITECTURE.md, REQUIREMENTS.md, TASKS.md, then Analyze (design first) |
| Product | PRODUCT.md, REQUIREMENTS.md, EXPERIENCE.md, ARCHITECTURE.md, TASKS.md, then Analyze |

In V2 the files are written one at a time, gated by open cards (see V2 · Expressiveness and token budget). On D1 (reference) the agent drafted them in this order in the background. The user never approves files one by one: they answer decision cards and adjust scope, flow and plan. A later file is drafted from the earlier ones. DECISIONS.md collects every answer and change with its reason.

## Shared parts to build once

The sidebar, inspector and status pill below are drawn for D1 and reused by V2. File states follow the V2 rules (Ready, Writing, Needs you, Waiting); the D1 states listed here are reference.

- **Sidebar** (same on B2, D1, B7, C1, C2, C3; the source of truth is D1):
  - Project switcher dropdown on top: project initial, name, branch. The menu lists every project with how many specs need the user, plus Add Project. A blue dot on the closed button means another project is waiting.
  - Project context row with its state (Up to date, Not read yet).
  - Specs of the selected project in three groups: Needs you (blue dot), Agent working (blue ring), Done (green dot). Each row: name, then "size · status" (for example "Product · 4 decisions"). Empty groups show a grey line ("Nothing waiting for you").
  - Under the open spec: Markdown files, collapsible, each with a file state: Written (green), Writing (blue ring), Waiting (grey ring), Edited (blue), Out of date and Stopped (orange, with the word).
  - Bottom: New Spec (Cmd+N) and the agent status, which opens Settings.
- **Inspector** (right column): on D1 the decision inbox; on C1 the decisions log.
- **Status pill** in the toolbar: what the agent is doing in the background.
- **Decision card**: kind (Conflict, Gap, Missing, Assumption), where it applies, a one-line question, two or three one-tap answers, then a collapsed answer with Change. In V2: one style plus the red "These disagree" card, and every card adds "Something else…" (free answer).
