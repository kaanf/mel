# Changelog

All notable changes to Mel. Versions follow [Semantic Versioning](https://semver.org); this file follows [Keep a Changelog](https://keepachangelog.com).

Downloads: [GitHub Releases](https://github.com/kaanf/mel/releases). From v0.2 on, Mel updates itself (**Mel › Check for Updates…**).

## [Unreleased]

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

[Unreleased]: https://github.com/kaanf/mel/compare/v0.3...HEAD
[0.3]: https://github.com/kaanf/mel/releases/tag/v0.3
[0.2.1]: https://github.com/kaanf/mel/releases/tag/v0.2.1
[0.2]: https://github.com/kaanf/mel/releases/tag/v0.2
[0.1]: https://github.com/kaanf/mel/releases/tag/v0.1
