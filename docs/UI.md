# UI

How the V2 screens are built. The design source is `docs/design/v2/` (read `FLOW.md` › V2 first); this file maps each drawn screen to its view and names what differs from the drawing. Live canvas: https://claude.ai/artifact/EoySYJYRhntvx3G6u19EFd

Rules for every screen:

- **Pixel-exact.** Colors, spacing, radii and type come from the `.dc.html` inline styles and live as named tokens in `Mel/Views/Theme.swift`. Views use tokens, never literals.
- **Light and Dark**, following the system, in a real macOS window (system traffic lights, corners and shadow). Light is the drawing. Dark isn't drawn: each color token carries a Dark value next to its drawn one (`Color(hex:dark:)`, `Color.ink` for neutral washes and hairlines), so no view decides anything per appearance. The mock's grey page and drawn window frame are not built.
- Every view has `#Preview`s for each state, built from `Views/Preview/PreviewData.swift`.
- A Debug build opens one fixture state with `-screen <name>` (`Views/Preview/DebugScreen.swift`): `start`, `noAgent`, `new`, `newEmpty`, `board`, `boardAsking`, `boardWaiting`, `boardWriting`, `boardStopped`, `boardUnplaced`, `boardChanged`, `boardEdited`, `ready`, `building`, `built`, `settings`, `specsSettings`.

## Window structure

```
WindowGroup (main)                         MainView
├── StartView                              no project yet, or first launch
├── NewView                                Start from an idea, before the first spec makes a project
└── NavigationSplitView
    ├── sidebar   SidebarView              project menu · Needs you / Building / Done · New · agent line
    └── detail    NewView                  nothing selected, or ⌘N
                  BoardView                the selected spec while it is planned
                  BuildView                after Start Building; ‹ Plan goes back to BoardView (V2-10)
Settings          SettingsView (tabs)      GeneralSettings · AgentSettings · SpecsSettings
```

`MainView` holds what the columns share: whether New is showing, and the file open in the board's center (the sidebar's file rows set it too).

## Screens

| Id | Drawn in | View | States |
|---|---|---|---|
| V2-0, V2-0b | V2-0-Start | `Views/Start/StartView` | agent ready, checking, not signed in, not working; no agent (install row, Check Again); no repos found |
| V2-1 | V2-1-New | `Views/New/NewView` | empty with examples; a guess with its reason; picked by the user; files attached; no project |
| V2-2 | V2-2-Board | `Views/Board/BoardView` + `BoardInbox`, `BoardPlan`, `BoardFileView`, `BoardTell` | asking (intake), cards open, waiting for answers (V2-9), file open and a change applied (V2-4), stopped (V2-5), change couldn't be placed (V2-7), Remove confirmation (V2-8), edited by hand, plan ready |
| V2-3 | V2-3-Ready | `Views/Build/BuildView` | start, midway (done, running, checking, failed, waiting), all done; Quick fix; prompt shown |
| V2-11 to V2-14 | V2-11-Build-Typing … V2-14-Build-Unplaced | `BuildView` + `Views/Board/BoardTell` (`building`) | telling Mel with a task chip, Mel changing files, change applied, unplaced |
| V2-10 | V2-10-Board-Plan | `Views/Board/BoardView` | the board with the plan ready, after ‹ Plan (`Spec.reopenPlan`) |
| V2-6 | V2-6-Settings-Specs | `Views/Settings/SpecsSettings` | project read, reading, not read, no project; adding a rule |
| C4 | Native-Settings-Agents | `Views/Settings/SettingsView` › `AgentSettings` | ready, not signed in, not found |
| sidebar | V2-1, V2-2, V2-3 | `Views/Main/SidebarView` | groups with rows and empty; New open; file rows; usage limit; missing project |

### Start

A 620 pt column centered in the window: logo, title, the "Your agents" line, the project list, the footnote and Start (↩). The list is the 5 most recently edited repos in `~/Developer`, then folders the user dropped, then "No code yet". A drop anywhere on the window adds a folder.

### New

One box (5 lines, grows no further; it scrolls), the attach button, the size chip and Start (⌘↩). Attached files show as chips inside the box; a drop on the box attaches. Under the box: the reason for the guess, or three examples while it is empty.

### Board

Center: the plan (Plan, Screens for a New product, Build order), or an open file. Right: "Mel needs you", 340 pt (drawn 300). While the agent runs, a working line sits above the center: what Mel is doing, the section a draft has reached, Watch and Stop. Under the center: Tell Mel with the result line or the unplaced offer above it. Toolbar: the spec's name and size, the status pill with "Write it now" while a file waits, Stop while the agent runs, the token total, Files and Start Building. Banners above the center: stopped, and edited by hand.

### Build

Toolbar: ‹ Plan, "Build: name", the status pill, Open Terminal here. Center, up to 820 pt: "n of N tasks done" with the next step, one bar segment per task, the built banner, then the steps (`BuildStep`: Run alone, At the same time in a grid of 260 pt cards, One after the other). A task card: state dot and word, number, title, "Builds … · changes …", its check command, then by state: Copy prompt; Check it, Copy again, Mark done without the check; the check running; the failed output with Copy fix prompt and Check again; Check passed at … with Reopen. Show prompt under every card that isn't waiting. Running and failed cards add "Tell Mel about this", which puts a task chip in Tell Mel, pinned under the steps (the board's `BoardTell` with `building`). While Mel changes files: the working line above the box, the pill "Mel is changing the files", Check it off on the chip's task only. After a change: the result line with tasks updated, added and changed after done; "Prompt changed · Copy again" on running and failed tasks whose prompt differs from the one copied (`TaskRun.prompt`); "Changed after done" with Reopen (never reopened by Mel); a new task with a New tag and a tinted card. Right, 280 pt: How building works, the same-step box, spec files, the AGENTS.md / commit / token line and Change in Settings.

Check it runs the task's `Verify` with `Check.run` (MelSystem): the user's login shell in the project folder, the last 20 lines kept. A task's state is `Spec.runs`; the last task done moves the spec to Done, Reopen moves it back to Building.

### Settings

A `TabView`: General (updates), Agents, Specs. Links that open Settings pick the tab first (`settingsTab`): the sidebar's agent line and Start's Change open Agents, Build's "Change in Settings" opens Specs.

### Sidebar

A 272 pt panel (drawn 244) inset 8 pt in the white window. A spec row's menu has Rename…, which changes the shown name only. The project button is a menu: the projects, "Locate …" for a missing one, Add Project…, Remove from the List, Move to Trash… (confirmed; the whole folder, code included, goes to the Trash; off while an agent runs). A gear at the end of the agent line opens Settings. A spec row is 40 pt: dot, name, one line (`Spec.sidebarNote`). Dots: Needs you blue (#C93400 while stopped), Building blue ring, Done green. A row's menu moves a handed-off spec between Building and Done.

## What differs from the drawing

| Drawn | Built | Why |
|---|---|---|
| Codex chip, install row, "Use Codex instead", "Continue with the other agent", Default agent | hidden | OQ #7, #28 |
| "Ask me before an agent changes the plan" | hidden | OQ #28 |
| V2-13 "Updated" tag on changed task cards | not shown | OQ #37: "Prompt changed" and "Changed after done" say it already |
| V2-11 "Check output" chip from a failed card | not sent | OQ #37: the output is for fixing code (Copy fix prompt), not for changing the plan |
| V2-12 Check it off on every task being changed; working line names TASKS.md and the tasks | off on the chip's task only; "Changing the passages your request touches" | OQ #37: which tasks change is known only when the reply arrives |
| V2-3 "2 of 7 tests failed", "· 9 tests" | "The check failed", "Check passed at 14:02" | Mel runs any project's command and can't count its tests |
| V2-3 Open Terminal here | opens Terminal in the project with `claude` running | The prompt is pasted into Claude Code |
| V2-3 for a Quick fix | one task, "the fix SPEC.md describes", no check command: Mark done | SPEC.md has no TASKS.md |
| "Task 3 of 7", "Merged yesterday" in the sidebar | "Building with Claude Code", "Built"; the user moves a spec to Done | OQ #34: Mel doesn't watch the coding agent |
| "Save specs to", Settings › Advanced | hidden | Not configurable; nothing to hold |
| "Read 2 days ago" in Settings › Specs | left out | No date kept |
| Quick fix chip "1 question, 1 file" | "1 file" | The intake may ask two |
| Time estimates | hidden | OQ #17 |
| sidebar 244, inbox 300, answer pills, Stop in the toolbar | sidebar 272, inbox 340, one answer per row with wrapping text, Stop in the working line | The user's feedback on 0.5: too narrow, answers ran out of the column, writing wasn't visible |
| not drawn | a sheet asking a New product's name after Start | The user's request: its folder takes the name |
| not drawn | Spec language row in Settings › Specs | Added in 0.4 (OQ #5) |
| not drawn | Settings › General with the update controls | Sparkle, since 0.2 |
| not drawn | not signed in / not working on Start's agent line; attached file chips on New | States the drawing doesn't cover, in the drawn components' look |

## Motion

One curve for the board, the sidebar and screen changes (`Animation.board`, a 0.28 s smooth spring) and one entrance for banners and cards (`AnyTransition.drop`: fade in from 6 pt above). Animations are tied to the value that changed (`.animation(_:value:)`), never to a whole view, so streaming text doesn't animate. The only repeating animations are the system spinner and the writing file's dot; both stop with Reduce Motion or when the run ends.

## Copy and tone

Short, plain sentences, no jargon, no exclamation marks. Title Case for buttons and menu items ("Start Building", "Check Again"), sentence case for links and quiet actions ("Write it now", "Something else…"). Ellipsis on buttons that open more UI. The words Mel uses for itself: "Mel" does things, "Claude Code" writes and builds. No time estimates.
