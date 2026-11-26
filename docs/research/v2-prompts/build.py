"""Builds the recorded prompts from core's templates: python3 -I build.py <probe-copy> <out-dir>

Mirrors Prompt.build (single-pass {{key}} replacement, {{rules}} = rules.md) and the MelSpec helpers
(promptText, filesText, kindsText, stepsText, answersText, decideText) on the probe inputs.
"""
import json, os, re, sys

probe, out = sys.argv[1:3]
here = os.path.dirname(os.path.abspath(__file__))
prompts = os.path.join(here, "../../../MelKit/Sources/MelSpec/Prompts")
os.makedirs(out, exist_ok=True)

def read(path):
    return open(path).read().strip()

def build(name, values):
    values = {"rules": read(f"{prompts}/rules.md") + "\n", **values}
    text = open(f"{prompts}/{name}.md").read()
    filled = re.sub(r"\{\{(\w+)\}\}", lambda m: values.get(m.group(1), m.group(0)), text)
    assert "{{" not in filled, name + ": unfilled " + filled[filled.index("{{"):][:40]
    open(f"{out}/{name}.md", "w").write(filled)

def section(name, text):  # ProjectContext.promptText style
    return f"### {name}\n\n{text.strip()}"

i = f"{probe}/inputs"
context = json.load(open(f"{i}/context.json"))
project = "\n\n".join(section(f".mel/project/{k}.md", context[k]) for k in ["product", "tech", "structure", "principles"])
feature = {"size": "Feature", "files": "REQUIREMENTS.md, ARCHITECTURE.md, TASKS.md",
           "kinds": "`requirements`, `architecture`, `tasks`"}
work = {"project": project, "name": "Breaks and daily goal", "idea": read(f"{i}/idea.txt"),
        "attachments": "- specs/breaks-and-goal/.mel/attachments/feedback.txt"}

build("project", {"mode": "This folder has code. Read it to learn the project."})
build("intake", {**feature, **work, "count": "3",
                 "topics": "- Main flows\n- Data and storage\n- Constraints\n- Milestones"})
build("requirements", {**feature, **work, "answers": read(f"{i}/answers.txt"), "decide": read(f"{i}/decide.txt"),
                       "approved": "(none yet)", "steps": read(f"{i}/steps.txt")})
build("analyze", {"name": work["name"], "kinds": feature["kinds"],
                  "approved": "\n\n".join(section(f + ".md", read(f"{i}/{f}.md")) for f in ["REQUIREMENTS", "ARCHITECTURE", "TASKS"]),
                  "earlier": "(none: this is the first check)"})
build("change", {**feature, "project": project, "name": work["name"], "idea": work["idea"],
                 "reading": "Everything you need is in this prompt. Do not read files or call tools.", "attachments": "(none)",
                 "requests": "- The long break comes after every 3rd focus session of the day, not every 4th.\n- REQUIREMENTS.md asked “Should the goal-reached message show the count?”. The answer: Yes, as `Goal reached: 8/8`.",
                 "current": "\n\n".join(section(f + ".md", read(f"{i}/{f}.md")) for f in ["REQUIREMENTS", "ARCHITECTURE", "TASKS"])})
print("built", sorted(os.listdir(out)))
