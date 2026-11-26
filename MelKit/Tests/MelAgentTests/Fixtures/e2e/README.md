Scripted (not recorded) runs for core's end-to-end tests in `MelTests/Session/EndToEndTests.swift`. Each file is one Mel run in the record shapes of the 2.1.311 recordings next door: `system/init`, `stream_event` text deltas, `assistant` `tool_use`, `result`. `fake-claude.sh` replays them through the real `AgentRunner` and `ClaudeCode.parse`.

`v2/` holds one script per spec size, named by prefix, in the order the tests run them:

- `qf-*`: Quick fix. `intake` (JSON in `result`), `spec`.
- `ft-*`: Feature. `intake`, `requirements` (reads the attachment), `architecture`, `tasks`, `analyze` (`{"issues": []}` in a fence; analyze replies hold contradictions only, coverage is Mel's own check). The project-context run before it is the real recording `claude-2.1.311-project-context.jsonl`.
- `pr-*`: Product. `intake`, `product`, `requirements-partial` (no `result`, replayed in `hang` mode to test Stop), `requirements-rest` (the resumed remainder, ends with a `<!-- mel:questions -->` trailer), `requirements-revised` (the round-2 answer as a patch: `{"edits": [{"old", "new"}]}` in `result`, like every revise run below), `requirements-full` (the whole file, for the redraft after a lost session), `experience`, `architecture`, `tasks`, `analyze-issues`, `tasks-fixed`, `analyze-passed`, `impact` (after an edit to REQUIREMENTS.md), then `experience-refined`, `architecture-refined`, `tasks-refined` and `analyze-passed` again.

Drafts carry `<!-- mel:step N -->` markers. A `hang` file stays under 10 lines because `hang` replays with `tail -f` (last 10 lines only), and its `Read` comes last, so once the session shows it, every delta has arrived.
