Scripted (not recorded) runs for core's end-to-end tests in `MelTests/Session/EndToEndTests.swift`. Each file is one Mel run in the record shapes of the 2.1.311 recordings next door: `system/init`, `stream_event` text deltas, `assistant` `tool_use`, `result`. `fake-claude.sh` replays them through the real `AgentRunner` and `ClaudeCode.parse`.

- `discovery-question.jsonl`, `discovery-done.jsonl`: Discovery turns (JSON in `result`).
- `draft-*.jsonl`: drafts. `draft-requirements-partial.jsonl` has no `result` and is replayed in `hang` mode to test Stop; it stays under 10 lines because `hang` replays with `tail -f` (last 10 lines only), and its `Read` comes last, so once the session shows it, every delta has arrived. `draft-requirements-rest.jsonl` is the resumed remainder.
