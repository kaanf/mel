# Changelog

All notable changes to Mel. Versions follow [Semantic Versioning](https://semver.org); this file follows [Keep a Changelog](https://keepachangelog.com).

Downloads: [GitHub Releases](https://github.com/kaanf/mel/releases). From v0.2 on, Mel updates itself (**Mel › Check for Updates…**).

## [Unreleased]

## [0.7] · 2026-11-27

### Added
- **Tell Mel while you build.** The Build screen has a Tell Mel box under the steps for what a task turned up: a missing state, a task that should be split, a wrong assumption. "Tell Mel about this" on a running or failed task says which task it came from. Mel patches the spec; a task whose prompt changed after you copied it says **Prompt changed · Copy again**, a finished task whose text changed says **Changed after done** and stays done until you reopen it, and new tasks show up in their step.

## [0.6] · 2026-11-27

### Changed
- **A new Build screen.** After the plan, Mel shows the tasks in steps: what runs alone, what can run at the same time in separate terminals, and what must wait. Copy a task's prompt into Claude Code; when it's finished, press **Check it** and Mel runs the task's check on your Mac, with no tokens. A failed check shows the error and a fix prompt. When every task is done, the spec moves to Done. **‹ Plan** takes you back to the plan.
- **Large specs scroll smoothly.** The board and the Build screen no longer re-read the files while you scroll.
- **Specs use far fewer tokens.** Mel now writes a spec in one ongoing Claude Code conversation, the way you would in Terminal, instead of sending every file again with each answer or change. What Claude has already seen comes from Claude's cache.

## [0.5.2] · 2026-11-27

### Added
- **Move a project to the Trash.** The project menu has Move to Trash…: after you confirm, the whole folder, code included, goes to the Trash, where you can get it back.
- **A Settings button** at the bottom of the sidebar, next to the Claude Code line.

### Changed
- **Mel picks the model.** Files and changes are written with Claude Opus 5.5; the first questions, the check and reading your project use the faster Claude Sonnet 5.5. Your Claude Code default model no longer matters.

## [0.5.1] · 2026-11-27

### Added
- **Dark mode.** Mel follows your Mac's appearance.
- **Name a new product.** Start asks what it is called; its folder takes the name. "Let Mel name it" keeps the old behavior.
- **Rename a spec.** Right-click it in the sidebar and choose Rename…. Mel still names a feature or a fix from your idea.
- **You can see Mel working.** While a file is written, a line under the toolbar says which file and which section it has reached, with Watch to read along and Stop. The file's dot pulses.

### Changed
- **Wider sidebar and question column**, so names and answers fit.
- **Answers on a card are one per row** and wrap, instead of pills that ran out of the column. Long "It must also" items wrap too instead of running under the question column.
- **Smoother.** Cards, banners, stories and screens now fade and slide into place instead of jumping.

## [0.5] · 2026-11-27

### Added
- **One board instead of thirteen screens.** Write what you want in one box and press Start. Mel asks up to three questions, then writes the files one at a time. You answer its questions in one place, "Mel needs you", and read a plan instead of approving files. The Markdown files are still there, one click away under Files.
- **Tell Mel.** One field under the plan: say what to change, add or remove in your own words. Mel changes only the passages it touches, logs why in DECISIONS.md, and you can undo it.
- **Remove and move stories.** Remove a story with everything built on it, or move it between First version and Later at once, with no agent run.
- **Ready.** One button, Build with Claude Code, opens Terminal with task 1. Task prompts and the files are below it.
- **Settings › Specs.** The defaults Mel no longer asks about: guessing small details, token use, the editor for Open in Editor, AGENTS.md, the Git commit, spec files in the sidebar, and the rules every agent follows.
- **Token use.** The board shows how many tokens a spec has used so far. Click it to see the split: questions, each file, checks and changes.

### Changed
- **Start in one screen.** Pick a repo, drop a folder or start from an idea. Mel reads the project in the background while you write.
- **Sidebar.** Specs of the current project in three groups: Needs you, Building and Done. Switch projects from the menu at the top.
- **No approval step.** Specs from 0.4 that were in review or in Analyze open on the board with their files and open questions.
- **Changes are patches.** When you answer a question or ask for a change, Claude Code sends only the passages that change and Mel puts them in place. The rest of the file stays word for word, and the run is shorter and uses fewer tokens. If Mel can't find where a change goes, nothing is changed and you can choose to rewrite that file.
- **Cheaper checks.** Mel checks by itself that every first-version criterion and quality requirement has a task. Claude Code only looks for contradictions between files, once, after the last file.
- **Settings has tabs:** General (updates), Agents and Specs.

### Removed
- The separate Discovery, Drafting, Review, Analyze and Refine screens, "Builds on" and the size picker on New Spec: the board and the size guess replace them.

## [0.4] · 2026-11-26

### Added
- **Spec language.** Welcome asks whether Claude Code should write your specs in English or Turkish; change it any time in Settings. Each spec keeps the language it was started in.

### Fixed
- Confirming an assumption no longer makes the assumptions below it show the confirmed text.

## [0.3] · 2026-11-24

Mel v2: a new design for the whole app.

### Added
- **Projects.** Pick a repo once; Mel reads it and writes short project context files that every spec and agent reads first, so new work extends your code instead of rebuilding it.
- **Three sizes.** Quick fix (one SPEC.md), Feature (Requirements, Architecture, Tasks) or Product (adds Product and Experience).
- **Analyze.** Before handoff, Mel checks the files against each other: contradictions, requirements with no task, uncovered quality needs, scope creep. Fix an issue with one click; a recheck keeps open issues and only adds real new ones.
- **Refine.** Edit an approved file, even in another app, and Mel marks what is now out of date, records why in DECISIONS.md, and updates only the affected parts.
- **Handoff.** A ready-to-paste prompt per task, with what it builds and how to verify it, plus an optional AGENTS.md written when you finish.
- Mel names the spec from your idea if you leave the name empty.

### Changed
- Discovery is replaced by a short intake: a few questions up front, then a short second round for gaps found in the draft.
- DESIGN.md is split into EXPERIENCE.md (Product) and ARCHITECTURE.md.
- Specs started from an idea without a repo go to ~/Developer.
- New look, light mode.

## [0.2.1] · 2026-11-23

The first version that arrives as an in-app update.

### Changed
- New honeycomb app icon.
- In narrow windows the toolbar keeps a short "Needs you" status instead of cutting it off.

### Fixed
- Pressing ↑ on PRODUCT.md in the sidebar now moves to Discovery.

## [0.2] · 2026-11-23

### Added
- **In-app updates.** Check for Updates… in the Mel menu and in Settings. This is the last version you install by hand.
- **Phased Discovery.** Questions come in file order (Product → Requirements → Design → Tasks), and each phase opens with a question you answer in your own words.
- The inspector groups coverage by phase.

### Changed
- DESIGN.md now starts with a User experience section.

### Fixed
- Toolbar status text no longer touches the edges of the toolbar.

## [0.1] · 2026-11-23

The first build: turn an idea into a four-file Markdown spec (PRODUCT, REQUIREMENTS, DESIGN, TASKS) with the Claude Code already on your Mac.

### Added
- Finds Claude Code on your Mac, even when Mel is opened from the Dock, and helps you sign in.
- Discovery: multiple-choice questions (keys 1–4), "You decide", Draft Now, and a coverage list.
- Drafting with a live preview and activity log. Stop and Resume continue where the agent left off.
- Review with assumptions to confirm or change, then Approve to unlock the next file.
- Mel is the only writer of your spec files; your own edits are never overwritten.
- Recovery when Claude Code stops (usage limit, signed out, crash), with a notification when you can continue.
- Spec ready: start command for Terminal, Show in Finder, optional Git commit of the spec.
- Library of specs in the sidebar; missing folders can be located again.
- Signed with Developer ID and notarized by Apple.

[Unreleased]: https://github.com/kaanf/mel/compare/v0.7...HEAD
[0.7]: https://github.com/kaanf/mel/compare/v0.6...v0.7
[0.6]: https://github.com/kaanf/mel/compare/v0.5.2...v0.6
[0.5.2]: https://github.com/kaanf/mel/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/kaanf/mel/compare/v0.5...v0.5.1
[0.5]: https://github.com/kaanf/mel/compare/v0.4...v0.5
[0.4]: https://github.com/kaanf/mel/compare/v0.3...v0.4
[0.3]: https://github.com/kaanf/mel/releases/tag/v0.3
[0.2.1]: https://github.com/kaanf/mel/releases/tag/v0.2.1
[0.2]: https://github.com/kaanf/mel/releases/tag/v0.2
[0.1]: https://github.com/kaanf/mel/releases/tag/v0.1
