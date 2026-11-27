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
| V2-3 | V2-3-Ready.dc.html | Build: tasks in steps (run alone, at the same time, one after the other), Copy prompt, Check it, Done; back to the plan | B7 |
| V2-6 | V2-6-Settings-Specs.dc.html | Settings › Specs: the defaults V2 stopped asking about | B1 fields, B7 toggles, A3 rules |

V2-0b, V2-4, V2-5, V2-7, V2-8, V2-9 and V2-10 are the same components as V2-0 and V2-2 with different props: build them as states, not screens.

Main path:

```
V2-0 Start ──Start──▶ V2-1 New ──Start──▶ V2-2 Board ──Start Building──▶ V2-3 Build ──‹ Plan──▶ V2-10 Board, plan ready
```

Rules that change from V1:

- **Size is inferred.** The agent classifies the request as Quick fix, Feature or New product from the text and the repo. One chip shows the guess; clicking it cycles the sizes. Files per size are unchanged (see "Spec files and their order").
- **Project context is read in the background** after Start on V2-0, once per repo. No screen waits for it. Its files and the rules (principles.md) are in Settings › Specs.
- **One inbox ("Mel needs you").** Before the draft: up to 3 intake questions, one at a time, with "Skip, write the plan now" (skipped ones become guesses). After each file: its decision cards, all in one style. Every question and card also offers "Something else…" for a free answer. Only a real contradiction gets the red "These disagree" card. No Conflict / Gap / Missing / Assumption labels.
- **4 file states only:** Ready (green dot), Writing (blue ring), Needs you (blue dot), Waiting (grey ring, not started yet). Stopped and out-of-date files show as Needs you, with the reason in the banner.
- **Files:** the Files button in the board toolbar lists the files. Clicking one opens it in the board's center: Formatted or Markdown, Open in Editor (Settings › Specs › Open files in), Reveal in Finder, Edit. A file still being written is read-only. DECISIONS.md is read-only (decisions change from their cards). Keyboard: ⌘1 to ⌘5 open the files in order, Esc returns to the plan. Settings › Specs › "Show spec files in the sidebar" (off by default) also lists them under the open spec.
- **Edit after it's written** (was C1): saving an edit shows a banner in the board with the files built on it, Update / Keep them as they are / Undo, and a "Why?" field saved to DECISIONS.md.
- **Agent stopped** (was C2): a banner in the board: Continue with the other agent, Resume when the limit resets, or Finish it myself (opens the file). Answers and finished files are untouched.
- **Plan tabs:** Plan, Screens, Build order. Screens appears only for New product.
- **Build** (V2-3, was Ready / B7): until Mel runs agents itself, the user runs each task's prompt in their own Claude Code. Tasks are grouped in steps from TASKS.md: Run alone, At the same time (only when the tasks change different folders; open one terminal each), One after the other (same folder). A step opens when the step before it is done. Each task: Copy prompt (short, names only the passages it needs, marks the task Running), Check it (Mel runs the task's verify command on this Mac: no agent, no tokens), passed → Done and the next tasks open, failed → the output, Copy fix prompt (includes the error), Check again. "Mark done without the check" and Reopen are always there. ‹ Plan goes to V2-10. When all tasks are done the spec moves to Done. When Mel runs agents later, Copy prompt becomes Run and Check it runs on its own; steps and checks stay. AGENTS.md, commit and "ask before an agent changes the plan" are on by default and live in Settings › Specs.

## V2 · Expressiveness and token budget

Users could write these files by hand in Claude, ChatGPT or Claude Code, so V2 holds two rules at once:

1. **Expressiveness.** The user can say anything in their own words, and change or remove anything easily, at any point.
2. **Token budget.** Mel never spends more tokens than doing it by hand, and less where it can. Tokens go on rewriting files, not on the user talking. Every change is a small patch to the affected passages; a file is never rewritten from scratch unless the user explicitly chooses it.

Rules that follow from them (all on V2-2 Board):

- **Tell Mel.** One free-text field under the board's center, also when a file is open: "Tell Mel what to change, add or remove…". Long text and attachments are fine. One request at a time against the current files; there is no chat and no history. Mel finds the passages the request touches and patches only those.
  - Result: one line, for example "Changed 2 places in REQUIREMENTS.md, 1 in ARCHITECTURE.md, 1 task in TASKS.md", with Undo. Changed passages are highlighted in the open file until the line is dismissed. (V2-4)
  - The change and its reason (the user's own words) are added to DECISIONS.md automatically.
  - Can't be placed: "Mel couldn't find where this goes in ARCHITECTURE.md." with Rewrite ARCHITECTURE.md (shows its cost) and Cancel. A whole-file rewrite only ever happens from this button, so it is always the user's explicit choice. Cancel puts the request back in the box. (V2-7)
  - Hidden while asking intake questions (there are no files yet), while editing a file by hand and while the agent is stopped.
- **Free answers.** Every intake question and decision card has "Something else…" next to its one-tap answers. It opens an inline text field; the typed answer is used exactly like a tapped one. An answered card shows the answer and Change.
- **Removing.** Each story card in Plan has a ··· menu with Remove…. A confirmation in the card lists what goes with it, for example "Also removes requirement 2.1, 2 screens in EXPERIENCE.md, the payments module in ARCHITECTURE.md and task 3", with Remove and Cancel (V2-8). Removing patches those passages out. Removed stories are logged in DECISIONS.md with Restore.
- **Scope moves are free.** Story cards drag between "First version" and "Later" (the Later / First buttons and the ··· menu do the same). It changes at once: no agent run and no progress indicator, because only the priority marker of that story changes.
- **Files are written one at a time, gated.** The next file starts only when the cards of the files before it are answered, so an answer never forces a rewrite of a later file. The waiting file reads "ARCHITECTURE.md starts after 2 answers" in Files and in the toolbar pill. A quiet "Write it now" link writes on without waiting; unanswered cards then become guesses, the same rule as "Skip, write the plan now". Not-started files are Waiting (grey ring) and can't be opened yet. (V2-9)
- **Token use is visible.** The board toolbar shows a small, neutral total for this spec, for example "41k tokens". Clicking it opens a popover by step: project context, questions, each file, checks, changes (V2-9). Settings › Specs › "Show token use on the board" (on by default) hides it. V2-3 Ready states the total in its summary.

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

Feature and Quick fix specs live in the chosen repo under `specs/<spec-name>/`. Product specs get a new folder.

| Size | Files, in order |
|---|---|
| Quick fix | SPEC.md |
| Feature | REQUIREMENTS.md, ARCHITECTURE.md, TASKS.md, then Analyze |
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
