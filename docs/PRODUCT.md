# Product

## Problem

People with an app idea (founders, designers, solo developers, small-business owners) can now get coding agents to build software, but the agents build badly from a vague prompt. What they need is a spec: who the users are, what the app must do, testable acceptance criteria, an architecture and an ordered task list. Writing that spec is slow, and most people don't know what a good one contains.

The agents that could help write it (Claude Code and others) live in the terminal, with no structure for discovery, no review step and no clear "done".

## Product

A native Mac app that runs a guided **idea → spec** pipeline:

1. **Idea** — the user names the project and describes it in plain words.
2. **Discovery** — the agent asks a few multiple-choice questions (about five) until the important topics are covered or explicitly left open.
3. **Draft** — the agent writes PRODUCT.md, then REQUIREMENTS.md, DESIGN.md and TASKS.md, one at a time.
4. **Review** — the user reads, edits, confirms assumptions and approves each file. The next file stays locked until the previous one is approved.
5. **Handoff** — four approved Markdown files plus a ready-to-run command that points a coding agent at them.

## Users

| User | Needs |
|---|---|
| Non-technical founder / product person | Plain language, no terminal, clear progress, confidence the spec is complete |
| Solo developer | Speed, plain Markdown in their repo, Git history, handoff to their agent of choice |
| Designer | A structured place to turn a brief into requirements they can review |

Every user already has Claude Code installed and signed in, or is willing to install it. The app never asks for an API key.

## Principles

These come straight from the design canvas and should drive every decision.

1. **Bring your own agent.** The app has no model and no account. It drives the agent CLI on the Mac with the user's subscription.
2. **The user owns the file.** During review only the user changes the file; the agent doesn't touch it. User edits are never overwritten.
3. **Plain Markdown on disk.** The spec is ordinary files in the user's folder, readable by any tool or agent. App metadata lives alongside, never inside, unless it is meaningful to the next agent (assumptions, open questions).
4. **Nothing is silently invented.** Gaps the agent fills are marked as assumptions. Unanswered questions stay marked as open questions in the file.
5. **Never lose work.** Stop, crash, usage limit: whatever is written is saved, approved files are untouched, and the user is offered a way forward.
6. **Native Mac.** HIG-correct macOS 26 app: sidebar, toolbar, inspector, sheets, keyboard shortcuts, notifications, Finder/Terminal integration.

## MVP scope

In:

- First-launch detection of Claude Code: found / not signed in / missing; Sign In via Terminal.
- New Spec sheet: name, idea, "let the agent fill small gaps", save location.
- Discovery: one question at a time, 1–4 keyboard choice, suggested answer, optional note, Decide Later, Draft Now, coverage checklist.
- Drafting with live progress, step list, activity log, live read-only preview, Stop.
- Review: rendered preview and editable raw Markdown, assumptions (confirm/change), open questions (answer now), Approve (⌘↩).
- Sequential gating of the four files.
- Failure recovery: partial result saved; resume later or finish by hand.
- Handoff: summary, copyable build command, Open in Terminal, optional Git commit, Show in Finder.
- Settings: General, Agents, Specs, Advanced.
- Multiple specs in the sidebar library (one agent run at a time).
- System notifications when a file is ready or an agent stops.

Out (not MVP):

- Designed but deferred: Pause/Resume, "Ask for changes" chat with inline suggestions, Review inspector (Agent / Questions / History), time estimates, parallel runs.

- Our own LLM backend, API keys, accounts, sync, collaboration.
- Agents other than Claude Code: Codex first, later others. The agent layer is built behind an adapter protocol so they can be added without touching the UI. Until then the canvas's "Continue with Codex", "Use Codex Instead" and default-agent picker are left out.
- Templates, custom file sets, extra spec files.
- Building the app from the spec inside Keel (we hand off to the agent).
- iOS / iPadOS.
- Mac App Store distribution. The app ships as a DMG (see [DESIGN.md › Distribution](DESIGN.md#distribution)).

## Success criteria

- A first-time user goes from idea to four approved files without opening Terminal (except for agent sign-in).
- Every acceptance criterion in a generated REQUIREMENTS.md is testable, and every task in TASKS.md references at least one criterion.
- No user edit is ever lost, and no approved file is ever changed without the user's action.
- A usage-limit stop is recoverable without restarting the spec.
