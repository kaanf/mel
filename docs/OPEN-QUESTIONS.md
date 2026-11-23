# Open questions

## Decided

| # | Question | Decision | Date |
|---|---|---|---|
| 1 | Product name | **Mel** | 2026-11-23 |
| 2 | Minimum macOS version | **macOS 26** | 2026-11-23 |
| 3 | Distribution | **DMG**, Developer ID signed + notarized, no sandbox, no Mac App Store | 2026-11-23 |
| 7 | Codex in the MVP? | **No.** Claude Code only; adapter protocol kept for later | 2026-11-23 |
| 4 | Who writes the spec files? | **Mel.** Claude Code runs read-only and streams Markdown; Mel appends it to the file | 2026-11-23 |
| 17 | Costly canvas features | **Deferred:** Pause, Ask-for-changes + suggestions, Review inspector/History, time estimates, parallel runs | 2026-11-23 |
| 6 | Discovery question limit / open questions | **No limit; no open questions.** Discovery runs until every topic is covered; files are complete, agent decisions are marked as assumptions | 2026-11-23 |
| 18 | Approve with unconfirmed assumptions? | **No.** Approve is disabled until every assumption is confirmed or changed | 2026-11-23 |
| — | Guiding priority | **Performance, speed, least complexity.** One target, no dependencies, no merge engine, no auto-retries | 2026-11-23 |

## Open

Each has a recommended default that the other docs already assume; change the docs if the answer differs.

| # | Question | Recommended default | Why it matters |
|---|---|---|---|
| 5 | Language of the app UI and of generated specs? | UI English (as designed); spec language follows the idea's language | Localization (e.g. Turkish) adds a String Catalog task |
| 9 | Keep `.mel/` in Git? | **No** (offer `.gitignore` entry) | App state is noise in the repo; the four files are the spec |
| 10 | Should "Save in" create `<folder>/<slug>/specs` or allow an existing project folder? | Both: if the chosen folder is an existing repo, use `<folder>/specs` | Developers will point it at an existing repo |
| 11 | Does the Jojo design system linked to the canvas matter for the native app? | **No**, use system components and semantic colors | None of the native screens use Jojo tokens |
| 12 | Model selection exposed in the UI? | Not in MVP; Advanced › extra CLI arguments covers it | Keeps New Spec simple |
| 13 | What does the Discovery "Edit…" on the idea do after questions were answered? | Edit the idea; agent re-checks coverage, answers kept | Undefined in the design |
| 14 | Settings tabs General, Specs, Advanced aren't designed | Use the proposal in UI.md | Needed for M3 3.2 |
| 15 | Telemetry / crash reporting? | None in MVP | Privacy promise: Mel makes no network calls |
| 19 | Bundle identifier | `com.kaanf.mel` (placeholder until the Apple Developer account is set up) | Needed in Wave 0 |
| 16 | Apple Developer account (for Developer ID + notarization) available? | Needed before M5 | Without it the DMG triggers Gatekeeper warnings |
