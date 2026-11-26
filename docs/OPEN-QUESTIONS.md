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
| 6 | Discovery question limit / open questions | **Replaced (v2 design).** Short intake (about 1–2 / 3 / 5 questions by size), then a round 2 for gaps found in the draft. Open questions may stay in a file, marked `[!OPEN QUESTION]` | 2026-11-23 |
| 18 | Approve with unconfirmed assumptions? | **Yes (v2 design).** "You can approve anyway": open items stay marked in the file for the next agent | 2026-11-23 |
| 20 | Target design | **v2 canvas** https://claude.ai/artifact/EoySYJYRhntvx3G6u19EFd (copy in `docs/design/v2/`), including the honeycomb logo. Built **pixel-exact**: colors, spacing, padding, radii, type as drawn. Items deferred in #7, #15, #17 stay deferred (Codex, Link Issue, Pause, inspector/suggestions/History, time estimates) | 2026-11-23 |
| 21 | Dark mode? | **No.** Light mode only (Aqua forced) | 2026-11-23 |
| 22 | Window chrome | **Real macOS window** (traffic lights, title bar, corners, shadow); only the content is pixel-exact | 2026-11-23 |
| 5 | Language of the app UI and of generated specs | **UI English.** Spec language asked on A1 Welcome (English or Türkçe, also in Settings › Specs), stored per spec; every prompt of the spec asks for it, Mel's markers stay English | 2026-11-26 |
| 23 | Next target design | **Canvas V2 simplified flow** (`FLOW.md` › V2, screens `V2-*`; summary in V2.md §0). Lanes A–C and D1 stay as reference. Built in Wave 8 | 2026-11-26 |
| 24 | Product rules for the flow | **Expressiveness and token budget.** The user can describe the product in their own words, and change or remove anything easily. Mel spends no more tokens than doing the same spec by hand in Claude, ChatGPT, Claude Code or Codex, and less where it can. Savings come from how changes are applied, never from limiting what the user can say | 2026-11-26 |
| 25 | Revise output | **Patches, not whole files.** The agent replies with `{old, new}` edits; Mel applies them. If one can't be placed, Mel changes nothing and offers "Rewrite FILE" with its cost; only that button rewrites a whole file | 2026-11-26 |
| — | Guiding priority | **Performance, speed, least complexity.** One target, no dependencies, no merge engine, no auto-retries | 2026-11-23 |

## Open

Each has a recommended default that the other docs already assume; change the docs if the answer differs.

| # | Question | Recommended default | Why it matters |
|---|---|---|---|
| 9 | Keep `.mel/` in Git? | **No** (excluded from the spec commit by pathspec) | App state is noise in the repo; the four files are the spec |
| 10 | Should "Save in" create `<folder>/<slug>/specs` or allow an existing project folder? | Both: if the chosen folder is an existing repo, use `<folder>/specs` | Developers will point it at an existing repo |
| 11 | Does the Jojo design system linked to the canvas matter for the native app? | **No**, use system components and semantic colors | None of the native screens use Jojo tokens |
| 12 | Model selection exposed in the UI? | Not in MVP; Advanced › extra CLI arguments covers it | Keeps New Spec simple |
| 13 | What does the Discovery "Edit…" on the idea do after questions were answered? | Edit the idea; agent re-checks coverage, answers kept | Undefined in the design |
| 14 | Settings tabs General, Specs, Advanced aren't designed | Use the proposal in UI.md | Needed for M3 3.2 |
| 15 | Telemetry / crash reporting? | None in MVP | Privacy promise: Mel makes no network calls |
| 19 | Bundle identifier | `com.kaanf.mel` (placeholder until the Apple Developer account is set up) | Needed in Wave 0 |
| 26 | Which tokens does the board count? | **Output + uncached input** per run (`result.usage`): closest to what counts against the user's limit without inflating it with cache reads | The canvas numbers (41k per spec, 1.8k per change) only match output tokens; full input would read about 5× higher |
| 27 | Who guesses the size on V2-1? | **Mel, locally** (keywords + repo or no repo, like the mockup); the chip corrects it | An agent run per Start costs tokens and time before anything is written |
| 28 | Drawn in V2 but deferred or new: Codex (V2-0, V2-3, V2-5), time estimates ("About 2 minutes", "Resume at 18:00"), "Ask before an agent changes the plan", "Build with Claude Code" opening Terminal | **Hidden** like V2.md §2, except **Build with Claude Code**: opens Terminal with `claude` and task 1's prompt (one `open`/AppleScript call, no new runtime) | Each is extra machinery; Build with Claude Code is the screen's one primary action |
| 29 | Invariant "never change an approved file without a user action" once approval is gone | **"Never change a Ready file without a user action"**: a card answer, Tell Mel, Remove, Update or Rewrite. "Never overwrite a user's edit" stays | CLAUDE.md and DESIGN.md state the old wording |
| 30 | Cheaper model for small runs (intake, impact, patches)? | **Not yet.** Measure with the token readout first; then decide per run kind | Lower usage, but a quality risk the user should judge |
| 16 | Apple Developer account (for Developer ID + notarization) available? | **Yes**: Team ID `SGWP227GBQ` ("Developer ID Application: Kaan Firat" in the login keychain); notarytool keychain profile `mel-notary` | Without it the DMG triggers Gatekeeper warnings |
