# UI

Screen-by-screen spec from the design canvas, mapped to SwiftUI. Canvas: https://claude.ai/artifact/45PrPjDYUrevUVJp2xNfUX

The canvas is a web mock of a macOS 26 app. Build the real thing with system components and materials (Liquid Glass comes free with standard toolbars, sidebars, sheets and buttons on macOS 26). Do not reproduce the mock's hex colors, shadows or hand-drawn traffic lights. Use semantic colors (`.primary`, `.secondary`, `.tint`, `.green`, `.orange`, `.purple`) so Light/Dark and Increase Contrast work.

The canvas also links a "Jojo" design system, but none of the screens use it; they follow the macOS HIG. We ignore Jojo for now (see OPEN-QUESTIONS).

## Window structure

```
WindowGroup (main)
└── NavigationSplitView
    ├── sidebar   SpecLibrarySidebar          (spec → Discovery + 4 files, status trailing)
    ├── detail    StageView (switches on selection + stage state)
    │             ├── DiscoveryView
    │             ├── DraftingView
    │             ├── ReviewView
    │             ├── FailureView
    │             └── EmptyLibraryView
    └── .inspector  StageInspector (per stage)
Window "Welcome"   (first launch, single instance)
Settings           (single pane: Agents; MVP)
Sheets             NewSpecSheet · SpecReadySheet
```

Toolbar: title + subtitle (spec name), status text, trailing actions per stage, inspector toggle (`.inspector` + `ToolbarItem` with `sidebar.trailing`).

Status colors used in the mock and their meaning:

| State | Mock color | SwiftUI |
|---|---|---|
| Ready / Approved / Done | green check | `.green` + `checkmark` |
| Agent running / Checking | pulsing purple dot | `.purple`, `symbolEffect(.pulse)` (off with Reduce Motion) |
| Needs you / Not signed in / Stopped | orange | `.orange` + `exclamationmark.circle` |
| Locked / Queued / Not yet | secondary | `.secondary` + `lock` |

## MVP deviations from the canvas

The canvas shows two agents (Claude Code, Codex). The MVP supports **Claude Code only** (Codex later, behind the same adapter). So:

- Welcome and Settings › Agents show a single agent row. The "Default agent for new specs" row is dropped.
- New Spec shows the agent as read-only text, no picker.
- Failure sheet drops "Continue now with Codex".
- Spec ready drops "Use Codex Instead".
- Settings › Agents drops the per-agent on/off switch (there is nothing to switch to).

Also left out of the first version to keep it small (see REQUIREMENTS.md › Later):

- Drafting: no Pause/Resume button (Stop + Resume only), no paused state.
- Review: no inspector (Agent chat, Questions, History tabs), no inline agent suggestions, no "Ask for changes" field.
- No time estimates ("About 2 min left", "about 1 min").
- Only one agent run at a time across all specs.

The sections below describe the MVP version.

## 0 · Welcome (first launch)

Artboard `Native-0-Welcome`. Centered window ~600 pt wide, no toolbar.

- App icon, "Welcome", subtitle: "Specs are written by the coding agent already on your Mac, using your own account. Here is what we found."
- Section "Coding Agent" with trailing "Scan Again" link button.
- Grouped list (inset, rounded) with one row: icon, "Claude Code", monospaced path, trailing status: Ready (green check) / Checking (pulsing dot) / Not signed in + "Sign In…" button / Not found + "Choose File…".
- Footnote: "Sign In opens Terminal with Claude Code's own login command. Not installed? Install it, then Scan Again, or choose the file manually."
- Footer: "You can change this later in Settings › Agents." + prominent "Continue" (enabled only when Ready; otherwise "Continue Without Agent" lets the user look around with New Spec disabled).

SwiftUI: `Form` with `.formStyle(.grouped)` or custom `List` section; `LabeledContent`; `.buttonStyle(.borderedProminent)` with `.controlSize(.large)`.

## 1 · New Spec sheet

Artboard `Native-1-NewSpec`. Sheet over the main window (main window empty state behind: "No Specs Yet / Start from an idea. The agent turns it into a spec with you.").

- Title "New Spec", subtitle "Describe your idea. The agent asks a few questions, then drafts the spec with you."
- Right-aligned label form (`Form` with `.formStyle(.columns)`):
  - Name: `TextField`
  - Idea: multi-line `TextField(axis: .vertical)` 6 lines, placeholder "What should it do, and for whom?", help "Plain words are fine. Say who uses it and what they do."
  - Agent: read-only "Claude Code" + "Found on this Mac"
  - Save in: folder pop-up (recent folders + "Choose…" → `fileImporter` / `NSOpenPanel` directory) and monospaced resulting path.
- Footer: help button (?), Cancel (`.cancelAction`), Continue (`.defaultAction`, disabled until valid).

## 2 · Discovery

Artboard `Native-2-Discovery`.

- Sidebar: spec expanded: Discovery (selected, badge "3 of 7" = topics covered), PRODUCT.md "Draft", REQUIREMENTS.md "Waiting", DESIGN.md "Queued", TASKS.md "Queued".
- Toolbar: title "Discovery", subtitle spec name; status "Needs you · Claude Code is waiting for an answer"; "Draft Now" button (help tooltip: "Skip the remaining questions. The agent decides the rest and marks each decision as an assumption."); inspector toggle.
- Content column (max ~620 pt, centered):
  - Stepper: Idea ✓ › Questions › Draft › Review.
  - "Your Idea" card with idea text + "Edit…".
  - "Answered" list: question → answer, each clickable.
  - Current question card: "Question 4" · "Shapes REQUIREMENTS.md"; title; why-text; radio options with note, "Suggested" badge and key hint 1–4, last option "You decide" ("The agent picks the best option and marks it as an assumption"); "Note for the agent (optional)" text field.
  - Footer: "Press 1 to 4 to choose. Answers can be changed later." · "Continue ↩" (default).
- Inspector: "Understanding 3 of 7" checklist (Covered ✓ / Asking ● / Not yet ○), footnote "Questions continue until every item is covered."; Agent "Claude Code · Spec mode"; Folder "specs/".

SwiftUI: custom radio rows (`Picker(.radioGroup)` cannot show notes and badges), `.onKeyPress(characters: "1234")`, `.keyboardShortcut(.defaultAction)`.

## 2b · Drafting

Artboard `Native-2b-Drafting`. Two modes: running / stopped (the canvas's paused mode is Later).

- Sidebar: PRODUCT.md Approved, REQUIREMENTS.md Writing|Stopped, DESIGN.md and TASKS.md Locked.
- Toolbar: title "Drafting"; status "Running · Writing story 3 of 5" with a thin progress bar under the toolbar (purple running, gray stopped); Stop.
- Stepper: Idea › Questions › Draft Requirements › Review.
- When stopped: banner "Stopped. Nothing was lost. Stories 1 and 2 are saved in REQUIREMENTS.md. You can review them now or let the agent continue." with "Continue Drafting" and "Review What's Written".
- Card "REQUIREMENTS.md · Claude Code": step list (Done / Running / Stopped / Next).
- Disclosure "Activity Log": timestamped monospaced lines (`12:04:39 wrote story 1 "Book a class" (3 criteria)`).
- "Up Next": DESIGN.md "Starts after you approve Requirements", TASKS.md "Starts after you approve Design".
- Footnote: "You can switch apps. You'll get a notification when Requirements is ready to review."
- Inspector = "Live Preview" of the file, rendered, read-only, with a trailing caret while running, and "Read only while the agent writes. You can edit once it's ready for review."

## 3 · Review

Artboard `Native-3-Review`.

- Sidebar: REQUIREMENTS.md "Review".
- Toolbar: file name; "Saved · your edits are never overwritten"; "Idle · DESIGN.md starts when you approve"; "2 of 4"; segmented Preview / Edit Markdown; Share; Show in Finder; "Approve ⌘↩" prominent. No inspector in the MVP.
- Document (Preview mode):
  - Title, summary line "5 stories, 14 acceptance criteria. Written from PRODUCT.md and your answers."
  - "Before you approve" box: "1 assumption to confirm" — "Confirm or change each assumption to approve." Approve stays disabled until none remain.
  - Story blocks: title, user story, numbered criteria with bold EARS keywords.
  - Assumption callout (Change… / Confirm).
- Edit Markdown mode: monospaced editable source (`TextEditor`; `NSTextView` only if large files feel slow).

## Failure · Agent stopped

Artboard `Native-Error-Partial`.

- Sidebar: DESIGN.md "Stopped", TASKS.md "Locked".
- Background: DESIGN.md partial draft (sections 1 and 2).
- Alert-style sheet: "Claude Code stopped while writing DESIGN.md"; plain explanation ("…your plan's usage limit was reached. This is a limit on your Claude account, not a problem with the spec. Nothing you approved was changed.").
- File state list: PRODUCT.md Approved, unchanged · REQUIREMENTS.md Approved, unchanged · DESIGN.md Stopped at section 3 of 6, Sections 1 and 2 saved · TASKS.md Not started.
- "What should happen next?" radio: Resume with Claude Code when the limit resets / Finish DESIGN.md myself. The primary button label follows the choice: Resume Later / Open File. When the cause is not a usage limit (crash, timeout), the first option is "Resume now" with button "Resume".
- Show Details · Not Now · primary.

## 4 · Spec ready

Artboard `Native-4-Done`. Sheet.

- "Spec ready" — "All four files are approved and saved as plain Markdown. Any coding agent can build from them."
- File list with green checks and summaries (Problem, users, scope · 5 stories, 14 criteria · 6 sections · 11 tasks, each linked to criteria).
- "Start building": "Run this in the project folder. It points the agent at your spec." Command box `claude "Read specs/ and implement TASKS.md, task 1"` + Copy (→ "Copied" 2 s). Link: Open in Terminal.
- Checkbox "Commit the spec to Git — Creates one commit in yoga-studio-booking so the spec has history."
- Footer: path · Show in Finder · Done.

## Settings › Agents

Artboard `Native-Settings-Agents`. `Settings { TabView }` with tabs General, Agents, Specs, Advanced (only Agents is designed).

- Claude Code group: name, status (Ready / Not signed in / Not found), version; Location (path, Change…); Account ("Signed in through the CLI", Open Terminal…).
- Detection group: "Look for the agent when the app opens" switch; Search paths list ("Your login shell's PATH" fixed first row, then editable paths) with +/−; footnote "Apps opened from the Dock don't see your Terminal PATH, so it is read from your login shell."; "Scan Now".

**MVP: Agents only** (decided 2026-11-23). Settings is a single pane with the Agents content above, no TabView. General, Specs and Advanced are out: notifications are controlled in System Settings, New Spec remembers recent folders, and extra CLI arguments would undermine the read-only invocation.

## Copy and tone

Short, plain sentences, no jargon, no exclamation marks. Title Case for buttons and menu items ("Scan Again", "Draft Now", "Review…"). Ellipsis on buttons that open more UI. No time estimates in the MVP.
