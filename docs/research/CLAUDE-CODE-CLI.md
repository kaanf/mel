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
- `--append-system-prompt "<text>"` works with this vector: the appended instruction was followed (fixture `claude-2.1.311-partial-messages.jsonl`). Use it for the stage contract instead of prefixing the stdin prompt.
- `--include-partial-messages` adds `stream_event` records (see below) and works with this vector.
- For a resumable session (Discovery chat, continuing a stopped draft) drop `--no-session-persistence` and add `--resume <session_id>` on the next run.
- An unknown `--resume` session ends the run immediately (exit 1, no model call, **no `init` record**) with a single `result`: `"subtype":"error_during_execution"`, `"is_error":true`, **no `result` field**, `"errors":["No conversation found with session ID: <id>"]`; the same text goes to stderr. Run fresh in that case.

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

`system` / `status` (`"status":"requesting"`, one per model request) also appears; ignore it.

### Partial messages (`--include-partial-messages`)

Observed 2026-11-23. Each `stream_event` record carries `session_id`, `parent_tool_use_id`, `uuid` and an `event` that is a raw Messages API stream event:

```json
{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"ELLO TH"}},"session_id":"…","parent_tool_use_id":null,"uuid":"…"}
```

- Per model request: `message_start` → `content_block_start` (`content_block.type` `text` or `tool_use`) → `content_block_delta`* → `content_block_stop` → `message_delta` (`stop_reason`) → `message_stop`.
- Text: `delta.type == "text_delta"`, `delta.text` is a chunk (a few characters to a few words). Tool input streams as `input_json_delta`; ignore it and use the whole `assistant` `tool_use` block for the activity log.
- The whole `assistant` message is **still emitted** (between the last delta and `content_block_stop`). With deltas on, take text only from `text_delta` and tool calls only from `assistant` blocks, or text is shown twice.
- Deltas of a request that ends in `tool_use` belong to that turn; the final answer is the text of the last request. `result.result` holds the final text only.

Not verified yet: the shape of a `rate_limit_event` / `result` when the limit is actually hit (only `"status":"allowed"` was recorded). Expect `status` other than `allowed` plus `resetsAt`; record a fixture when it happens.

## Signed out

Observed when not signed in: the run ends in ~50 ms at no cost, with

- an `assistant` text block `"Not logged in · Please run /login"`
- `result`: `"is_error": true`, `"terminal_reason": "api_error"`, `"result": "Not logged in · Please run /login"`, `"total_cost_usd": 0`

So a minimal probe run would also detect it, but there is a free subcommand; use that.

## Auth status (`claude auth status`)

Verified 2026-11-23. No model call, returns in well under a second.

- `claude auth status` prints JSON by default (`--json`; `--text` for human-readable). Exit code **0 when signed in, 1 when signed out**.
- Signed in: `{"loggedIn": true, "authMethod": "claude.ai", "apiProvider": "firstParty", "email": …, "orgId": …, "orgName": …, "subscriptionType": "pro", …}`.
- Signed out: `{"loggedIn": false, "authMethod": "none", "apiProvider": "firstParty", …}`.
- Mel's check: run it with the same environment allowlist as a run, read `loggedIn`. Treat `authMethod` other than `"claude.ai"` (e.g. Console/API key) as not usable: Mel is subscription only. `init`'s `apiKeySource == "none"` stays the run-time guard.
- Login command for Terminal: `claude auth login` (subscription is the default; `--console` would switch to API billing, never pass it).

## Structured output

The read-only run in `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-read-only-run.jsonl` asked for JSON in the prompt only (no schema flag). The model returned a bare JSON object as the `result` text (`{"wrote_notes": false, "files_read": [...], "questions": [...]}`), which parsed directly.

Re-verified 2026-11-23 with a Discovery-style prompt, `--tools Read,Glob,Grep`, `--append-system-prompt "…Reply with JSON only."` and partial messages (`../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-discovery-json.jsonl`): one `Read` of a file in `cwd`, then `result.result` was a bare `{"questions":[{"id","text","options"}]}` object with no prose or code fence, which parsed directly. 2 turns, ~$0.02. No schema flag needed for Discovery.

## Fixtures

Real recordings, safe to commit (no secrets; `cwd` paths point at disposable probe folders):

| File | What |
|---|---|
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-signed-out.jsonl` | Signed-out run (3 records) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-read-only-run.jsonl` | Read-only run with `Read,Glob,Grep`, returns JSON questions (11 records) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-edit-run-short.jsonl` | Write-enabled run, short (6 records) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-edit-run-long.jsonl` | Write-enabled run with tool use and thinking tokens (24 records) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-partial-messages.jsonl` | Read-only run with `--include-partial-messages` and `--append-system-prompt`, text only (15 records) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-discovery-json.jsonl` | Read-only Discovery-style run with partial messages: `Read` tool call, then a JSON-only answer |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-auth-status-signed-in.json` | `claude auth status` signed in (email/org replaced with placeholders) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-auth-status-signed-out.json` | `claude auth status` signed out (no `USER` in the environment) |
| `../../MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-unknown-resume.jsonl` | `--resume` with an unknown session ID (1 record) |

They live in `MelKit/Tests/MelAgentTests/Fixtures/` and drive the adapter and runner tests.
