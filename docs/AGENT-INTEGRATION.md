# Agent integration

> Updated for the V2 board in Wave 8 (8.6).

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
  --tools Read,Glob,Grep \         # --tools "" when AgentRequest.allowsTools is false (init then lists tools: [])
  --permission-mode manual --permission-prompts none \
  --disable-slash-commands --no-chrome \
  --model claude-opus-5-5 \        # claude-sonnet-5-5 for AgentModel.light: intake, check, project context
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
- `result` → `done`, or when `is_error`, classify (signed out, usage limit, other). Before either, `result.usage` → `usage(tokens:)`: `output_tokens + input_tokens + cache_creation_input_tokens` (OQ #26; cache reads don't count). `SpecSession` adds it to `Spec.tokens[step]` in `state.json`; steps are `questions`, one per file, `checks` (the contradiction check) and `changes` (change runs, rewrites). The project context run belongs to no spec and isn't counted. A run stopped before its `result` isn't counted.
- An unknown `--resume` session fails at once with an error result: run fresh.
- Ignore every other record type. Decode only the fields above.

## Stage protocols

Two kinds of stage output. Every run uses the same read-only invocation above; only the prompt changes. Fixtures for every shape below are in `MelKit/Tests/MelAgentTests/Fixtures/` (recorded 2026-11-23 on 2.1.311 with core's prompts in `MelKit/Sources/MelSpec/Prompts/`; [research/v2-prompts/](research/v2-prompts/) has the inputs and scripts to re-record).

### Structured (JSON) stages

The agent returns one JSON object as the final `result` text; Mel decodes it. No schema flag: ask for "one JSON object and nothing else". Verified: the model sometimes wraps the object in a ```json fence (the analyze recording), so decoders take the outermost `{…}`. If decoding fails, show the error with a Retry button.

| Run | When | Prompt gets | Returns | Decoder | Fixture | Time |
|---|---|---|---|---|---|---|
| Project context | after Start, in the background; Settings › Specs › Read Again | repo (agent reads it), `mode` | `{"product", "tech", "structure", "principles", "read", "sources"}`: Markdown of the four `.mel/project/` files | `ProjectContext.decode` | `project-context` | ~22 s, 9 turns |
| Intake | a new spec's board opens | context, idea, size and its files, attachment paths, topics, question count, kinds | `{"name", "coverage": [CoverageItem], "questions": [question]}`, every intake question at once | `Intake.decode` | `intake` | ~16 s |
| Check | after the last file; "Check again" | every written file inline, the contradictions still open | `{"issues": […]}`, contradictions only | `AnalyzeResult.contradictions(in:)` | `analyze` | ~28 s, 1 turn, no tools |
| Change | card answers, Tell Mel, Update, Remove, Restore | the requests, every written file inline, attachment paths | `{"edits": [{"file", "old", "new"}]}` | `Change.decode` | `change` | no tools without attachments |

Field rules:

- **Question** (intake and draft trailer): `{"id", "title", "about", "why", "shapes", "options": [{"label", "note", "suggested"}]}` (`about`: the topic in two or three words, optional, shown on the card). `options: []` takes a typed answer. Exactly one option has `suggested: true`. The card adds "Something else…".
- **Coverage item** (intake): `{"label", "state"}`, `state` `covered` or `notYet`.
- **ProjectContext.structure** has `## Modules` with lines `- Name — path` (em dash).
- **Analyze reply** (8.3): `{"issues": [{"id", "location", "text", "ids", "actions"}]}`, contradictions only. `ids` lists the requirements it is about (may be `[]`); exactly 2 actions `{"label", "fix", "files": [DocKind]}`, the second primary. Everything else in `AnalyzeResult` is Mel's own check by ID, with no agent (`AnalyzeResult.coverage`): the coverage rows (task = an ID in a task's `Covers`, test = that task has `Verify`, screen = an ID on a flow's `Covers` line or in the screens table), the stats, and a `noTask` / `qualityNotCovered` issue for each P1 criterion or quality requirement without a task. P2/P3 criteria need no task. `AnalyzeResult.add` puts the contradictions first and marks their rows `conflict`. `scopeCreep` is no longer produced.

- **Change** (board, `change.md`): `{"edits": [{"file", "old", "new"}]}`, a Patch across the written files; `file` is a `DocKind` raw value (a file name is accepted). `Change.apply` places every edit or none; `unplaced(in:)` names the files that need "Rewrite FILE". One run serves all waiting requests (`Spec.changeRequests`: card answers and issue fixes) or one Tell Mel, Update or Remove request. Without attachments it runs with no tools.
- **Patch**: the edits of one file, `{"edits": [{"old", "new"}]}`. `Patch.apply` replaces each `old` with `new`, in order; `old` must occur exactly once, character for character. `Change` applies one per file (fixture `revise` is a recorded one-file patch run).

The check and a change without attachments pass the files inline and run with `allowsTools: false` (`--tools ""`). The prompt must then say not to read files: with no tools and a prompt that invites reading, the model writes tool calls as plain text and the run never finishes (seen: 11+ min).

### Change runs (OQ #25, #31)

Every change after a file is written runs `change.md` once over all written files: the card answers given since (together, once no card is open), one Tell Mel request, Update after an edit by hand, Remove and Restore. No stored session. Mel places the edits and writes the files; everything outside them stays word for word. Nothing streams into a file, so a stopped run leaves the files untouched.

Unplaced: nothing changes. `Spec.unplacedChange` keeps the reply and names the files where an edit didn't fit; the board offers "Rewrite FILE" (with the tokens that file's draft cost) or Cancel. Rewrite runs `rewrite.md`, a streaming whole-file stage like drafting, for one file; when no unplaced file is left, the edits that did fit go in. It is the only way a whole file is written again. Cancel drops the change and hands a typed request back to Tell Mel.

### Streaming Markdown stages (drafting, rewrite)

The agent outputs only the file's Markdown; Mel shows the text deltas live and saves the final `result`. One comment is stripped before saving (and `<!-- mel:step N -->` lines, which drafts wrote before 0.5):

- **Gap questions**: at most one trailing `<!-- mel:questions` + newline + JSON array of up to 3 questions (shape above; the model may leave out `shapes`, which then defaults to the file's kind) + newline + `-->` at the very end. Absent when there are no gaps. They become cards in "Mel needs you", next to one card per `[!OPEN QUESTION]` callout left in the file.

The trailer is **split across text deltas** (recorded: `"<!-"` + `"- mel:questions\n["`). Strip from the accumulated text, never per delta, and hold back a trailing partial `<!--` from the live preview until it closes.

The prompt lists the file kind's steps (`DocKind.draftSteps`) as a writing checklist; nothing reports progress through them.

### Attachments

New and Tell Mel copy files into `specs/<slug>/.mel/attachments/`; prompts list their paths relative to the project folder, and the agent opens them with Read. Verified under the read-only flags (fixture `attachments`): a `.log` comes back as numbered text, a `.png` as an `image` tool result the model describes. The files are inside the working directory, so no extra permission or `--add-dir` is needed. The step line reads `read attachments/<file>`.

## Prompts

Prompts are Markdown files in the app bundle (`MelKit/Sources/MelSpec/Prompts/`) with `{{placeholders}}` filled by plain string replacement (`Prompt.build`), owned by core; the placeholders per prompt are pinned in `PromptTests.placeholdersPerPrompt`. Every prompt includes the four project context files (`ProjectContext.promptText`) when they exist.

Drafting prompts: open questions (`> [!OPEN QUESTION]`) and assumptions (`> [!ASSUMPTION]`) may be written into a file. With "Let Mel guess small details" off, gaps become open questions instead of assumptions. Questions the user skipped ("Skip, write the plan now", "Write it now") are passed as "decide and mark as assumption". With a spec language set, `language.md` is appended to every prompt of that spec.

## Failure classification

| Signal | StopReason | User copy |
|---|---|---|
| `rate_limit_event.status` not `allowed`, or error result mentioning a limit; reset time from `resetsAt` | `usageLimit(resetsAt)` | "…your plan's usage limit was reached. This is a limit on your Claude account, not a problem with the spec." |
| `is_error` + "Not logged in" | `signedOut` | "Claude Code is signed out. Sign in again, then resume." + Sign In… |
| Non-zero exit, no recognized error | `crashed` | "Claude Code stopped unexpectedly." + Show Details |
| No stdout for 120 seconds | `timeout` | "Claude Code stopped responding." |
| User pressed Stop | `user` | The board's "Paused" banner |

Keep the matching strings in one table in the adapter, covered by fixture tests.

## Recovery

- **Resume** (the stopped banner): a cut-off draft runs the `continue` prompt with `--resume <sessionID>` from its last complete section; an unknown session writes the file again. A stopped change or check runs again. For a usage limit with a known `resetsAt`, Resume waits for it and posts a notification then. No automatic runs.
- **Finish it myself**: the cut-off file counts as written and opens for editing; the board goes on from there.

## Later: Codex

Not in the MVP. When added, it is a `CodexAdapter` (verify flags then):

```
codex exec --json --sandbox read-only --skip-git-repo-check -C <project folder> \
  [--output-schema <schema file>] [resume <session_id>] -
```

Events: `thread.started` → `sessionStarted`; agent message items → `textDelta` (whole messages, chunkier live preview); `turn.completed` / `turn.failed` / `error` → `finished` / `failed`. Auth: `codex login status`, login `codex login`.

The UI then gains back what the canvas shows: the Codex chip on Start, Default agent in Settings › Specs, "Continue with the other agent" on the stopped banner (continue prompt with the partial file, no cross-agent session resume), and "Use Codex instead" on Ready.
