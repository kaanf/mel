# Agent integration

> Updated for v2 in Wave 6 (stage protocols, prompts, attachments). Where it still differs from [V2.md](V2.md), V2.md wins.

How Mel finds, runs and recovers Claude Code. The MVP supports Claude Code only; Codex comes later as a second `AgentAdapter` (notes at the end). This is the riskiest part of the product: the CLI changes often. Flags marked verified were observed on Claude Code 2.1.311 (see [research/CLAUDE-CODE-CLI.md](research/CLAUDE-CODE-CLI.md), with real recorded fixtures). Anything else must be verified in task M1 1.1.

## Detection

1. Build the search list: login-shell `PATH` (`$SHELL -l -i -c 'printf %s "$PATH"'`, 5 s timeout, ignore shell noise before the last line), then the configured extra paths (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.npm-global/bin`, `~/.bun/bin`), then a per-agent override from Settings.
2. Find the first executable `claude` in the list. Resolve symlinks for display only; run the path as found.
3. Run `<exe> --version` (timeout 5 s) to confirm it works and record the version.
4. Check authentication (below). Result: `ready`, `notSignedIn`, `missing`, `broken(error)`.

Run detection off the main actor; show "Checking" until it finishes. Re-run when the app becomes active after a Sign In.

### Authentication check

- Verified: when signed out, any `claude -p` run ends in ~50 ms at no cost with `result.is_error: true`, `terminal_reason: "api_error"`, `result: "Not logged in · Please run /login"`. Match on `is_error` + "Not logged in".
- Verified (2.1.311): `claude auth status` prints JSON for free, exit 0 when signed in and 1 when signed out. Read `loggedIn`; `authMethod` must be `claude.ai` (subscription). Use it for detection instead of a probe run.
- Login command (opened in Terminal): `claude auth login`.

## Running a stage

Common invocation rules:

- Working directory: the project folder (parent of `specs/` and `.mel/`), so the agent can read existing code and attachments.
- Environment: `HOME`, `USER` (verified: without `USER` the CLI reports "Not logged in"), login-shell `PATH`, `TERM=dumb`, `NO_COLOR=1`. Nothing else: an allowlist, never the app's own environment.
- **Subscription only, never the API.** Claude Code must run on the user's Claude subscription (their `claude` sign-in). The allowlist above keeps out `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX` and similar, which would switch the CLI to API billing. Check the `init` record: `apiKeySource` must be `"none"`; otherwise stop the run and show an error.
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

Also verified (2.1.311), and part of every stage run:

- `--include-partial-messages`: emits `stream_event` records with `text_delta`. Whole `assistant` messages still arrive, so take text **only from the deltas**, and tool calls (activity steps) from the `assistant` blocks.
- `--append-system-prompt <stage contract>`: works with the read-only vector above.

Record mapping:

- `system/init` → `session(id)` (stored for `--resume`).
- `stream_event` text deltas (if enabled) or `assistant` `text` blocks → `text`.
- `assistant` `tool_use` blocks (`Read`, `Glob`, `Grep`) → `step("read specs/PRODUCT.md")`.
- `rate_limit_event` → remember `rate_limit_info.resetsAt` (Unix seconds) for the usage-limit message.
- `result` → `done`, or when `is_error`, classify (signed out, usage limit, other).
- An unknown `--resume` session fails at once with an error result: run fresh.
- Ignore every other record type. Decode only the fields above.

## Stage protocols

Two kinds of stage output. Every run uses the same read-only invocation above; only the prompt changes. Fixtures for every shape below are in `MelKit/Tests/MelAgentTests/Fixtures/` (recorded 2026-11-23 on 2.1.311 with the provisional prompts in [research/v2-prompts/](research/v2-prompts/); re-record with `record.py` there when core's prompts land).

### Structured (JSON) stages

The agent returns one JSON object as the final `result` text; Mel decodes it. No schema flag: ask for "one JSON object and nothing else". Verified: all recorded runs returned bare JSON (no code fence). If decoding fails, show the error with a Retry button.

| Run | Screen | Prompt gets | Returns | Decoder | Fixture | Time |
|---|---|---|---|---|---|---|
| Project context | A3 | repo (agent reads it), new-project flag | `{"product", "tech", "structure", "principles"}`: Markdown of the four `.mel/project/` files | `ProjectContext.decode` | `project-context` | ~23 s, 8 turns |
| Intake | B2 | context, idea, size and its files, builds-on, attachment paths, topics, question count | `{"coverage": [CoverageItem], "questions": [question]}`, all round-1 questions at once | core (intake type) | `intake` | ~24 s |
| Analyze | B6 | every approved file inline | `AnalyzeResult` JSON | `AnalyzeResult.decode` | `analyze` | ~56 s, 1 turn |
| Impact | C1 | the edit as a unified diff, the stale files inline | `{"items": [{"kind", "what", "count"}]}` | `ImpactResult.decode` | `impact` | ~4 s |

Field rules:

- **Question** (intake and draft trailer): `{"id", "title", "why", "shapes", "options": [{"label", "note", "suggested"}]}`, the v1 Discovery question. `options: []` is an open question. Exactly one option has `suggested: true`. The app adds "You decide".
- **Coverage item**: `{"label", "phase", "state"}`; `phase` is a `DocKind` raw value of the spec's size; `state` is `covered`, `asking` or `notYet`.
- **ProjectContext.structure** has `## Modules` with lines `- Name — path` (em dash), which B1's "Builds on" chips read.
- **AnalyzeResult**: `stats` (4 × `{"value", "label"}`), `issues` (`{"id", "kind", "location", "text", "actions"}`, `kind` ∈ `contradiction`, `noTask`, `qualityNotCovered`, `scopeCreep`, exactly 2 actions `{"label", "fix", "files": [DocKind]}`, the second primary), `coverage` (`{"id", "text", "screen", "architecture", "task", "test"}`, marks `covered`/`missing`/`conflict`, `screen` is `null` without EXPERIENCE.md).
- **ImpactResult**: one item per stale file in file order, `kind` a `DocKind` raw value, `"what": "Nothing"` and `"count": "0"` when unaffected.

Analyze and Impact pass the files inline and say "do not read other files": one turn, no tool calls. Intake and Project context let the agent read the repo.

### Streaming Markdown stages (drafting, revise)

The agent outputs only the file's Markdown; Mel shows the text deltas live and saves the final `result`. Two kinds of comment, both stripped before saving:

- **Step markers** `<!-- mel:step N -->` on their own line, N counting from 1, before each step of the file kind's fixed checklist (`DocKind.draftSteps`, listed in the prompt). B3 moves the checklist to the highest N seen. Verified: all 7 markers arrive in order, but two can come back to back (steps 2 and 3 written together), so never assume one marker per section.
- **Gap questions**: at most one trailing `<!-- mel:questions` + newline + JSON array of up to 3 questions (shape above, `shapes` is the file's kind) + newline + `-->` at the very end. Absent when there are no gaps. They become round-2 questions in B4.

Markers and the trailer are **split across text deltas** (recorded: `"<!-- mel:"` + `"step 1 -->"`, `"<!-"` + `"- mel:questions\n["`). Strip from the accumulated text, never per delta, and hold back a trailing partial `<!--` from the live preview until it closes.

The v1 plan line (`5 stories`) is gone; progress is the step markers.

### Attachments

B1 copies files into `specs/<slug>/.mel/attachments/`; prompts list their paths relative to the project folder, and the agent opens them with Read. Verified under the read-only flags (fixture `attachments`): a `.log` comes back as numbered text, a `.png` as an `image` tool result the model describes. The files are inside the working directory, so no extra permission or `--add-dir` is needed. The step line reads `read attachments/<file>`.

## Prompts

Prompts are Markdown files in the app bundle (`MelKit/Sources/MelSpec/Prompts/`) with `{{placeholders}}` filled by plain string replacement (`Prompt.build`), owned by core. Every prompt includes the four project context files when they exist. The provisional v2 texts used for the fixtures are in [research/v2-prompts/](research/v2-prompts/): `context.md`, `intake.md`, `draft-requirements.md`, `analyze.md`, `impact.md`.

Drafting prompts: open questions (`> [!OPEN QUESTION]`) and assumptions (`> [!ASSUMPTION]`) may stay in a file (V2.md §5, OQ #18). With "Let Mel fill small gaps" off, gaps become open questions instead of assumptions. Topics answered "You decide", and topics left at Draft Now, are passed as "decide and mark as assumption".

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
