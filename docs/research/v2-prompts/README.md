# Re-recording the v2 fixtures

The v2 fixtures (`MelKit/Tests/MelAgentTests/Fixtures/claude-2.1.311-{project-context,intake,draft-steps,analyze,impact,attachments}.jsonl`) are real runs of core's prompts in `MelKit/Sources/MelSpec/Prompts/`. `V2FixtureTests` checks the streams, `V2DecodeTests` runs core's decoders over them.

- `probe/`: the probe projects and the inputs. `focus-timer/` is a small Swift package (`TimerCore`, `SessionStore`, `FocusTimer`) with the Feature idea "short and long breaks plus a daily goal". `inputs/` holds the values: `REQUIREMENTS.md` comes from an earlier draft run; `ARCHITECTURE.md` and `TASKS.md` are hand-written with planted issues (`config.json` vs `settings.json`, story 6 without a task, a sound task nothing asks for, Q4 uncovered); `before.md`/`after.md` change the long break from every 4th to every 3rd session.
- `build.py <probe-copy> <out-dir>`: fills core's templates from `inputs/`, mirroring `Prompt.build` and the MelSpec text helpers. Update it when `PromptTests.placeholdersPerPrompt` changes.
- `record.py [--no-tools] <prompt> <probe-folder> <out.jsonl>`: `--no-tools` mirrors `allowsTools: false` (`--tools ""`, analyze and impact); 300 s timeout. Runs `claude` with `ClaudeCode.arguments`' flags and the env allowlist, and rewrites the probe path to `/tmp/mel-probe`, also inside split `input_json_delta` chunks.

**Copy `probe/` out of the Mel repo first** (e.g. into the session scratchpad, then `git init` the `focus-timer` copy). Run inside this repo, Claude Code would also load Mel's own CLAUDE.md from the parent folders.

```sh
cp -R $R/probe $W && cd $W && (cd focus-timer && git init -q && git add -A && git commit -qm init)
python3 -I $R/build.py $W prompts
python3 -I $R/record.py prompts/project.md focus-timer out/project-context.jsonl
# inputs/context.json is the context the other fixtures were recorded with; replace it (and re-record them) only when their prompts change
python3 -I $R/build.py $W prompts
python3 -I $R/record.py prompts/intake.md focus-timer out/intake.jsonl
python3 -I $R/record.py prompts/requirements.md focus-timer out/draft-steps.jsonl
python3 -I $R/record.py --no-tools prompts/analyze.md focus-timer out/analyze.jsonl
python3 -I $R/record.py --no-tools prompts/impact.md focus-timer out/impact.jsonl
python3 -I $R/record.py inputs/attach-prompt.md probe-attach out/attachments.jsonl
```

Check new recordings for secrets (`grep -iE 'Users/|private/|sk-ant'`) and `"apiKeySource":"none"` before committing.
