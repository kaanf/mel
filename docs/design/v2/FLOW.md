# Mel screen flow

Read this file first. It maps every screen file in this folder to its place in the app, what it is for, and where each button leads.

## How to read a screen file

- Each `*.dc.html` file is one screen of the native macOS app, drawn as an HTML mockup. Build it in SwiftUI; do not ship the HTML.
- The top of every file has a `MEL SCREEN` comment with the screen id, purpose, entry points and exits. It matches the table below.
- Markup inside `<x-dc>` is the layout. `{{name}}` holes are filled by `renderVals()` in the `<script>` at the bottom. That script holds sample data and UI state; treat it as the view model's shape, not real logic.
- An `href="Native-....dc.html"` is a navigation edge to that screen. `href="#"` means "not wired in the mockup".
- Sample content (Yoga Studio Booking, yoga-studio-booking repo) is placeholder data.
- `Mel-Logo.dc.html` is the app icon and its usage, not a screen.

## Lanes

- **A · First run**: from first launch to a project Mel has read.
- **B · Write a spec**: the main loop, from a new spec to handoff.
- **C · Other states**: screens reached from conditions, not from a single button.

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
| B3 | Native-2b-Drafting.dc.html | Drafting | Live progress while the agent writes a file. Stop and resume. |
| B4 | Native-3-Review.dc.html | Review a file | Review REQUIREMENTS.md: priorities, MVP line, quality requirements, edge cases, assumptions, open questions. The same layout reviews PRODUCT.md, ARCHITECTURE.md and TASKS.md. |
| B5 | Native-3b-Experience.dc.html | Review EXPERIENCE.md | Flows, screens and their states, visual direction. Missing states are flagged. |
| B6 | Native-3c-Analyze.dc.html | Analyze | Cross-file check before handoff: coverage matrix and issues (contradiction, no task, quality not covered, scope creep). |
| B7 | Native-4-Done.dc.html | Spec ready | Handoff: per-task prompts with verify commands, AGENTS.md, keep-in-sync, commit. |
| C1 | Native-3d-Refine.dc.html | Refine after edit | User changed an approved file. Downstream files are marked out of date; reason is saved as a decision. |
| C2 | Native-Error-Partial.dc.html | Agent stopped | The agent stopped mid-file (for example a usage limit). Approved files are untouched; choose how to continue. |
| C3 | Native-E3-Home.dc.html | Home, no specs | Main window with no specs yet. Shown on reopen or after cancelling New Spec. |
| C4 | Native-Settings-Agents.dc.html | Settings › Agents | Choose and configure the coding agents. |

## Main path

```
A1 Welcome ──Continue──▶ A2 Pick a project ──Read This Repo──▶ A3 Project context ──Save and Start a Spec──▶ B1 New Spec
A1x No agent ──Check Again──▶ A1      A2 ──Start from an Idea──▶ A4x First spec ──Start──▶ B2

B1 ──Start──▶ B2 Intake ──Continue / Draft Now──▶ B3 Drafting ──Review What's Written──▶ B4 Review
B4 ──Approve──▶ (B3 drafts EXPERIENCE.md) ──▶ B5 Review EXPERIENCE ──Approve──▶ (B3 + B4 for ARCHITECTURE.md, TASKS.md) ──▶ B6 Analyze ──Hand Off Anyway / after fixes──▶ B7 Spec ready
```

## Conditional screens

- **C1** opens when the user edits a file that is already approved. Exit: Refine (agent updates the out-of-date files, reviewed in B4) or Keep Them as They Are.
- **C2** opens when the agent process stops before a file is finished. Exit: resume later, continue with the other agent, or finish the file by hand in B4.
- **C3** is the main window state with zero specs.
- **C4** opens from A1x (Choose path…) and from the app menu.

## Spec files and their order

Feature and Quick fix specs live in the chosen repo under `specs/<spec-name>/`. Product specs get a new folder.

| Size | Files, in order |
|---|---|
| Quick fix | SPEC.md |
| Feature | REQUIREMENTS.md, ARCHITECTURE.md, TASKS.md, then Analyze |
| Product | PRODUCT.md, REQUIREMENTS.md, EXPERIENCE.md, ARCHITECTURE.md, TASKS.md, then Analyze |

Each file is drafted (B3), then reviewed (B4, or B5 for EXPERIENCE.md). A file unlocks only after the one before it is approved. DECISIONS.md collects every answer and change with its reason.

## Shared parts to build once

- **Sidebar**: project row, spec name, one row per file with a status: Waiting, Queued, Drafting, Review, Approved, Locked, Out of date, Stopped.
- **Inspector** (right column): Agent chat, Questions, References, History or Decisions tabs.
- **Status pill** in the toolbar: what the agent is doing and "n of m" files.
- **Suggestion pattern**: the agent suggests, only the user changes a file (Accept / Reject inline).
