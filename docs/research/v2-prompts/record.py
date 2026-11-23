"""Records a fixture: python3 -I record.py <prompt.md> <probe-folder> <out.jsonl> [key=value | key=@file ...]

Fills {{key}} in the prompt, runs claude with ClaudeCode.arguments' flags and the app's environment allowlist,
and writes the stream with the probe folder's parent replaced by /tmp/mel-probe, also where a path is split
across input_json_delta chunks (each tool input's chunks are joined into its first delta). Check for secrets
before committing.
"""
import json, os, subprocess, sys

prompt_path, cwd, out = sys.argv[1:4]
prompt = open(prompt_path).read()
for pair in sys.argv[4:]:
    key, value = pair.split("=", 1)
    prompt = prompt.replace("{{" + key + "}}", open(value[1:]).read().strip() if value.startswith("@") else value)
assert "{{" not in prompt, "unfilled " + prompt[prompt.index("{{"):][:40]

args = ["claude", "-p", "--output-format", "stream-json", "--verbose", "--input-format", "text",
        "--include-partial-messages", "--restricted", "--strict-mcp-config", "--tools", "Read,Glob,Grep",
        "--permission-mode", "manual", "--permission-prompts", "none", "--disable-slash-commands", "--no-chrome",
        "--no-session-persistence"]
env = {"HOME": os.environ["HOME"], "USER": os.environ["USER"], "PATH": os.environ["PATH"], "TERM": "dumb", "NO_COLOR": "1"}
run = subprocess.run(args, input=prompt, capture_output=True, text=True, cwd=cwd, env=env)

old = os.path.dirname(os.path.realpath(cwd))
records = [json.loads(line) for line in run.stdout.splitlines()]
chunks, message = {}, None
for r in records:
    e = r.get("event", {}) if r.get("type") == "stream_event" else {}
    if e.get("type") == "message_start":
        message = e["message"]["id"]
    if e.get("type") == "content_block_delta" and e["delta"].get("type") == "input_json_delta":
        chunks.setdefault((message, e["index"]), []).append(e["delta"])
for deltas in chunks.values():
    joined = "".join(d["partial_json"] for d in deltas)
    for i, d in enumerate(deltas):
        d["partial_json"] = joined if i == 0 else ""
with open(out, "w") as f:
    for r in records:
        f.write(json.dumps(r, ensure_ascii=False, separators=(",", ":")).replace(old, "/tmp/mel-probe") + "\n")
print("exit", run.returncode, "records", len(records), run.stderr[:300])
