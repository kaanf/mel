# Agent integration

How Mel finds, runs and recovers Claude Code. The MVP supports Claude Code only; Codex comes later as a second `AgentAdapter` (notes at the end). This is the riskiest part of the product: the CLI changes often. Flags marked verified were observed on Claude Code 2.1.311 (see [research/CLAUDE-CODE-CLI.md](research/CLAUDE-CODE-CLI.md), with real recorded fixtures). Anything else must be verified in task M1 1.1.

## Detection

1. Build the search list: login-shell `PATH` (`$SHELL -l -i -c 'printf %s "$PATH"'`, 5 s timeout, ignore shell noise before the last line), then the configured extra paths (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.npm-global/bin`, `~/.bun/bin`), then a per-agent override from Settings.
2. Find the first executable `claude` in the list. Resolve symlinks for display only; run the path as found.
3. Run `<exe> --version` (timeout 5 s) to confirm it works and record the version.
4. Check authentication (below). Result: `ready`, `notSignedIn`, `missing`, `broken(error)`.

Run detection off the main actor; show "Checking" until it finishes. Re-run when the app becomes active after a Sign In.

### Authentication check

- Verified: when signed out, any `claude -p` run ends in ~50 ms at no cost with `result.is_error: true`, `terminal_reason: "api_error"`, `result: "Not logged in · Please run /login"`. Match on `is_error` + "Not logged in".
- To verify: whether an `auth` status subcommand exists (cheaper than a probe when signed in). Otherwise probe with a minimal run and cache the result for the session.
- Login command (opened in Terminal): `claude auth login` if it exists, otherwise `claude` then `/login`.

## Running a stage

Common invocation rules:

- Working directory: the project folder (parent of `specs/`), so the agent can read existing code if any.
- Environment: `HOME`, `USER` (verified: without `USER` the CLI reports "Not logged in"), login-shell `PATH`, `TERM=dumb`, `NO_COLOR=1`. Do not pass the app's own environment wholesale.
- Prompt goes through **stdin**, not argv (length limits, escaping).
- New process group (`setpgid`) so stop signals reach child processes.
- Tools: no file writes, no shell. Reads of the project folder are allowed.
- Output: newline-delimited JSON on stdout; stderr captured (last 64 KB) for "Show Details".

### Claude Code

Verified read-only vector (2.1.311):

```
claude -p \
  --output-format stream-json --verbose \
  --input-format text \
  --restricted --strict-mcp-config \
  --tools Read,Glob,Grep \
  --permission-mode manual --permission-prompts none \
  --disable-slash-commands --no-chrome \
  [--resume <session_id>]           # verified; drop --no-session-persistence to allow it
  [--no-session-persistence]        # for one-shot runs that will never be resumed
```

To verify in M1 1.1: `--include-partial-messages` (text deltas for the live preview; without it text arrives as whole `assistant` messages) and `--append-system-prompt` (otherwise put the stage contract at the top of the stdin prompt).

Record mapping:

- `system/init` → `session(id)` (stored for `--resume`).
- `stream_event` text deltas (if enabled) or `assistant` `text` blocks → `text`.
- `assistant` `tool_use` blocks (`Read`, `Glob`, `Grep`) → `step("read specs/PRODUCT.md")`.
- `rate_limit_event` → remember `rate_limit_info.resetsAt` (Unix seconds) for the usage-limit message.
- `result` → `done`, or when `is_error`, classify (signed out, usage limit, other).
- An unknown `--resume` session fails at once with an error result: run fresh.
- Ignore every other record type. Decode only the fields above.

## Stage protocols

Two kinds of stage output.

### Structured (JSON) stages

Used for Discovery (and later "Ask for changes"). The agent must return one JSON object. Use the CLI's schema flag if M1 1.1 confirms it exists; otherwise ask for JSON only and decode the final result text. If decoding fails, show the error with a Retry button. No automatic retry loop.

Discovery turn request: idea, answers so far, coverage list, `fillGaps`, max questions (default 5). Response:

```json
{
  "coverage": [
    { "label": "Problem", "state": "covered" },
    { "label": "Payments", "state": "asking" },
    { "label": "Cancellations", "state": "notYet" }
  ],
  "next": {
    "id": "payments",
    "title": "How do members pay?",
    "why": "Decides whether the spec covers checkout, refunds and receipts.",
    "shapes": "requirements",
    "options": [
      { "label": "Class packs bought in the app", "note": "You mentioned buying class packs in your idea", "suggested": true },
      { "label": "Paid at the desk, app only books", "note": "No checkout in the app; staff adds credits" },
      { "label": "Monthly membership with auto-renew", "note": "Subscription, unlimited booking" }
    ]
  },
  "done": false
}
```

The app always appends the "Not sure yet" option itself. `done: true` with no `next` ends Discovery. The first turn also proposes the coverage list from the idea.

Later, ask-for-changes response: `{ "reply": "…", "suggestions": [{ "find": "…", "replace": "…" }] }` (see SPEC-FORMAT.md › Suggestions).

### Streaming Markdown stages

Used for drafting the four files. The agent outputs only the file's Markdown. For REQUIREMENTS.md and TASKS.md the first line is a plan (`5 stories`, `11 tasks`) that Mel strips. Progress = `##` sections written vs. planned (DESIGN.md is always 6). The current step label is the last `##` heading ("Writing story 3 of 5: Cancel a booking"). No other markers.

## Prompts

Prompts are Markdown files in the app bundle (`Mel/Spec/Prompts/`: `discovery.md`, `product.md`, `requirements.md`, `design.md`, `tasks.md`, `continue.md`) with `{{placeholders}}` filled by plain string replacement. Each embeds the relevant section of [SPEC-FORMAT.md](SPEC-FORMAT.md).

Fill-gaps policy text:

- on: "When information is missing and a reasonable default exists, use it and wrap it in a `> [!ASSUMPTION]` callout."
- off: "When information is missing, do not invent it; add a `> [!OPEN QUESTION]` callout."

Topics the user answered "Not sure yet" or "Decide Later" are always written as open questions.

## Failure classification

| Signal | StopReason | User copy |
|---|---|---|
| `rate_limit_event.status` not `allowed`, or error result mentioning a limit; reset time from `resetsAt` | `usageLimit(resetsAt)` | "…your plan's usage limit was reached. This is a limit on your Claude account, not a problem with the spec." |
| `is_error` + "Not logged in" | `signedOut` | "Claude Code is signed out. Sign in again, then resume." + Sign In… |
| Non-zero exit, no recognized error | `crashed` | "Claude Code stopped unexpectedly." + Show Details |
| No stdout for N seconds (default 120, Settings › Advanced) | `timeout` | "Claude Code stopped responding." |
| User pressed Stop | `user` | Inline "Stopped. Nothing was lost." banner, no sheet |

Keep the matching strings in one table in the adapter, covered by fixture tests.

## Recovery

- **Resume**: run the `continue` prompt with `--resume <sessionID>`. For a usage limit with a known `resetsAt`, post a notification at that time; the user taps Resume. No automatic runs.
- **Finish myself**: switch to Review in Edit Markdown mode; the stage counts as finished when the user approves.

## Later: Codex

Not in the MVP. When added, it is a `CodexAdapter` (verify flags then):

```
codex exec --json --sandbox read-only --skip-git-repo-check -C <project folder> \
  [--output-schema <schema file>] [resume <session_id>] -
```

Events: `thread.started` → `sessionStarted`; agent message items → `textDelta` (whole messages, chunkier live preview); `turn.completed` / `turn.failed` / `error` → `finished` / `failed`. Auth: `codex login status`, login `codex login`.

The UI then gains back what the canvas shows: default agent picker (Welcome, New Spec, Settings), "Continue now with Codex" on the failure sheet (continue prompt with the partial file, no cross-agent session resume), and "Use Codex Instead" on Spec ready.
