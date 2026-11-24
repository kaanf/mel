# Wave 7 real run (2026-11-24)

Debug build of main f67c61f (`com.kaanf.mel.debug`, fresh defaults), Claude Code 2.1.311 at `/opt/homebrew/bin/claude`. Driven through the accessibility API (no computer-use tools), so wall-clock times include scripting overhead; agent times are from screen and file timestamps. Screenshots: `w7-real-run/`.

## Run 1: Feature on an existing repo (B1 → B7)

Repo: a git copy of `v2-prompts/probe/focus-timer` (3 Swift modules, no specs). Idea: "Add short and long breaks after focus sessions, plus a daily goal of focus sessions that focus log shows progress against."

| Step | Agent time | Result |
|---|---|---|
| Repo read (A3, via B1's read button) | 21 s | 4 context files + 7 principles, accurate |
| Intake | 20 s | 3 questions |
| REQUIREMENTS.md | ~50 s | 5 stories, 26 criteria, 8 quality; round 2: 3 gaps |
| ARCHITECTURE.md | ~78 s | 4 sections; round 2: 2 gaps |
| TASKS.md | ~62 s | 7 tasks; round 2: 1 gap |
| Analyze | ~45 s | 26/26, 8/8, 1 contradiction with 2 fix choices |
| B7 + Commit to Git | <1 s | commit "Add spec for Untitled Spec": `.mel/project`, AGENTS.md, spec, 7 task prompts |

Total agent time ~4.6 min; wall clock ~16 min.

## Run 2: Product from an idea (A4x → B7)

B1 › Add Project… › Start from an Idea. Idea: "A small Mac app for a climbing gym: members book a slot on the bouldering wall, see how full each hour is, and cancel up to 12 hours before."

| Step | Agent time | Result |
|---|---|---|
| Intake | ≤26 s | 5 questions |
| PRODUCT.md, **Stop** at ~25 s | — | "Stopped · 5 of 6 steps saved", 6.1 kB on disk |
| **Continue Drafting** | 17 s | review |
| **Round 2** (3 questions, picked the non-suggested no-show block) | 32 s | block rule in PRODUCT.md |
| REQUIREMENTS.md | ~2.5 min | 14 stories, 79 criteria, 16 quality |
| EXPERIENCE.md | ~91 s | 12 flows, 25 screens; diagram and states render well |
| ARCHITECTURE.md | ~140 s | 25 kB |
| TASKS.md | ~172 s | 39 tasks |
| Analyze | ~129 s | 6 contradictions + 1 scope creep |
| **Fix 7 Issues** (4 revisions, 5 approvals, re-Analyze) | ~7.8 min | 7 → 2 issues, both new |
| Hand Off Anyway → B7 | — | |
| **Edit** PRODUCT.md outside Mel (12 → 24 hours) | ~8 s to detect + impact | PRODUCT Edited, 4 files Out of date, Analyze Rerun |
| **C1 Refine** (4 revisions, 5 approvals, re-Analyze) | ~7 min | D-07 "Members can cancel up to 24 hours before the start"; 2 → 4 issues |
| Hand Off Anyway → B7 | — | "5 files approved, 4 Analyze issues left open" |

Total agent time ~28 min; wall clock ~38 min. Stop/Resume, round 2, the Analyze fix, impact title and C1 all work end to end.

## Bugs

### ui

1. **First-run "Read This Repo" skips the repo read.** Fresh defaults → Welcome → pick a folder → Read This Repo lands on Home with "No context"; no A3 run starts. `MainView.swift:43` shows the first-run `SetupFlow` only while `state.projects` is empty, so `addProject` swaps it for the library before `.projectSetup` shows. Workaround: B1's read button. (`01-read-repo-skipped.png`)
2. **Spec never gets a name.** B1 says "Mel suggests a name once you describe your idea", but it stays "Untitled Spec" through intake, drafting and B7. The folder (`specs/untitled-spec`), commit message and AGENTS.md all say Untitled. Both runs. (Might need core: which reply carries the name?)
3. **Start from an Idea creates `~/untitled-spec`** in the home folder with no folder choice, and the name is "untitled" because of (2). A second idea spec would collide.
4. **Live Preview goes blank after Stop** although "Nothing was lost" and PRODUCT.md has 6.1 kB. Repro: Product, Stop while drafting. (`05-live-preview-blank-after-stop.png`)
5. **Live Preview shows raw Markdown** (`**Member**`) while streaming; the review view renders it. (`04-live-preview-raw-bold.png`)
6. **B7 shows inline code as raw backticks** in task titles (Feature run). (`03-b7-raw-backticks.png`)
7. **TASKS.md review: Priority/Reads/Verify bullets render outdented** to the left of the numbered task title. (`02-tasks-bullets-outdented.png`)
8. **Stale state after an outside edit.** After PRODUCT.md is edited and 4 files are Out of date, B7 changes from "5 files approved, 2 Analyze issues left open" to "5 files approved." instead of saying files are out of date. Opening an Out-of-date file shows no out-of-date banner, and the status pill still says "Idle · EXPERIENCE.md starts when…, 2 of 5". (`06-…`, `07-…`)
9. **Discovery count doesn't move.** The sidebar's Discovery row stays at "2 of 7" (Feature) and "1 of 10" (Product) after all intake questions are answered.
10. **EXPERIENCE.md toolbar has only Approve**: no rendered/source, folder or share buttons like the other files. Flow rows end with a dangling arrow before wrapping.
11. **Accessibility: most buttons have no label.** Sidebar rows, B1 cards, Setup buttons and C1 Refine/Keep expose only "button" to VoiceOver (toolbar items are labeled). Also made scripting this run slow.

### core

1. **Analyze issues don't converge.** Product: 7 → (fix) 2 new → (refine) 4, with the 2 left open coming back unchanged plus 2 more. Each rewrite round adds contradictions (headcount definition, schema test vs Q4, staff landing screen, gymPhone scope creep). (`08-…`, `09-…`)
2. **TASKS cites its own wrong task numbers** (assumption blocks off by one: 21 for task 20 and so on); Analyze caught it.
3. **Analyze stat card changes unit between runs** ("14 of 14 requirement stories" vs "79 of 79 criteria").
4. **Feature Analyze: Test column says "Missing"** for 1.4, 1.5, 1.7, 2.5… but no issue lists the missing tests and the header says "1 issue". Decide whether missing tests count.
5. **AGENTS.md doesn't mention `.mel/project`** although B7 says it "points every agent at the project context".

### platform (me)

- Driving the app needs the Debug window on the active Space. Earlier today it kept vanishing while another app was frontmost in a different Space; once it shared the active Space it stayed put. Not a Mel bug.
- `com.kaanf.mel.debug` is shared with the test host, so test runs and real runs share defaults (the stray `/Users/kaan/untitled-spec` "Missing" project at the start likely came from an earlier idea run). Real runs should start with `defaults delete com.kaanf.mel.debug`.
