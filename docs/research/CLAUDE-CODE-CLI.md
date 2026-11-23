# Claude Code CLI: verified behavior

Carried over from the previous project in this repository (Jojo), which drove Claude Code from a helper process and verified its behavior against the real CLI. Everything here was **observed on Claude Code 2.1.311** (2026-11-16 to 2026-11-18). The same version is installed on the development Mac (`/opt/homebrew/bin/claude`). Re-check when the CLI version changes (task M1 1.1).

The old implementation lives in git history (`crates/jojo-domain/src/claude.rs`, `crates/jojo-domain/tests/m1_claude.rs`, `m2_planner.rs`), if a detail is missing here.

## Read-only invocation (what Mel needs)

Verified argument vector for a fresh, read-only, non-interactive run. The prompt goes on stdin.

```
claude -p \
  --output-format stream-json --verbose \
  --input-format text \
  --restricted \
  --strict-mcp-config \
  --tools Read,Glob,Grep \
  --permission-mode manual \
  --permission-prompts none \
  --no-session-persistence \
  --disable-slash-commands \
  --no-chrome
```

- `--tools Read,Glob,Grep` limits the built-in tools; the `init` record lists exactly `["Glob","Grep","Read"]`.
- `--permission-mode manual` + `--permission-prompts none`: anything that would ask for permission is denied. The `init` record reports this mode as `"default"`.
- `--restricted` + `--strict-mcp-config`: no MCP servers, no ambient config.
- For a resumable session (Discovery chat, continuing a stopped draft) drop `--no-session-persistence` and add `--resume <session_id>` on the next run.
- An unknown `--resume` session ends the run immediately with an error result and no model call; run fresh in that case.

With write tools (for reference, Mel doesn't use this): `--tools Read,Edit,Write,Glob,Grep --permission-mode acceptEdits`. Edits inside the working directory are applied; writes outside it, to `.git/config`, and shell commands are refused.

## Environment

- The CLI needs **`HOME` and `USER`**. With only `HOME` it reports "Not logged in"; with both it is signed in (sign-in is stored per account name).
- Add the login-shell `PATH` so the CLI and anything it spawns resolve. Don't pass the app's whole environment.
- No API key involved: `init` shows `"apiKeySource":"none"` for subscription sign-in.

## Stream records

One JSON object per line. Records seen with the flags above (no `--include-partial-messages`):

| `type` / `subtype` | Use in Mel |
|---|---|
| `system` / `init` | `session_id`, `tools`, `permissionMode`, `model`, `claude_code_version`, `cwd` |
| `system` / `thinking_tokens` | ignore |
| `assistant` | `message.content[]`: `text` blocks (the answer), `tool_use` blocks (`Read` / `Glob` / `Grep` → activity log line) |
| `user` | tool results; ignore |
| `rate_limit_event` | `rate_limit_info`: `status` (`"allowed"` seen), `resetsAt` (Unix seconds), `rateLimitType` (`"five_hour"`), `unifiedWindows` with per-window `utilization` and `resetsAt` |
| `result` | `subtype`, `is_error`, `terminal_reason`, `result` (final text), `session_id`, `num_turns`, `duration_ms`, `total_cost_usd` |

Not verified yet:

- `stream_event` text deltas need `--include-partial-messages`. Without it, text arrives as whole `assistant` messages. Needed for a smooth live preview while drafting; verify in M1 1.1.
- The shape of a `rate_limit_event` / `result` when the limit is actually hit (only `"status":"allowed"` was recorded). Expect `status` other than `allowed` plus `resetsAt`; record a fixture when it happens.

## Signed out

Observed when not signed in: the run ends in ~50 ms at no cost, with

- an `assistant` text block `"Not logged in · Please run /login"`
- `result`: `"is_error": true`, `"terminal_reason": "api_error"`, `"result": "Not logged in · Please run /login"`, `"total_cost_usd": 0`

So a minimal probe run is a cheap, reliable sign-in check when signed out. When signed in it costs a small model call; prefer an `auth` status subcommand if M1 1.1 finds one.

## Structured output

The read-only run in `fixtures/claude-2.1.311-read-only-run.jsonl` asked for JSON in the prompt only (no schema flag). The model returned a bare JSON object as the `result` text (`{"wrote_notes": false, "files_read": [...], "questions": [...]}`), which parsed directly. Good enough for Discovery; a schema flag is optional.

## Fixtures

Real recordings, safe to commit (no secrets; `cwd` paths point at disposable probe folders):

| File | What |
|---|---|
| `fixtures/claude-2.1.311-signed-out.jsonl` | Signed-out run (3 records) |
| `fixtures/claude-2.1.311-read-only-run.jsonl` | Read-only run with `Read,Glob,Grep`, returns JSON questions (11 records) |
| `fixtures/claude-2.1.311-edit-run-short.jsonl` | Write-enabled run, short (6 records) |
| `fixtures/claude-2.1.311-edit-run-long.jsonl` | Write-enabled run with tool use and thinking tokens (24 records) |

Move them to `MelTests/Fixtures/` when the Xcode project exists.
