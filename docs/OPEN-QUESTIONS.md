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
| 26 | Which tokens does Mel count? | **Output + uncached input** per run: `output_tokens + input_tokens + cache_creation_input_tokens` from `result.usage`. Cache reads are left out | 2026-11-26 |
| 27 | Who guesses the size on V2-1? | **Mel, locally** (keywords + repo or no repo, like the mockup); the chip corrects it. No agent run | 2026-11-26 |
| 28 | Drawn in V2 but deferred | **Hidden:** Codex (V2-0, V2-3, V2-5), time estimates, "Ask before an agent changes the plan". **Built:** Build with Claude Code opens Terminal with `claude` and task 1's prompt | 2026-11-26 |
| 31 | When are a file's card answers applied? | **Together, in one change run, once every open card is answered** (or on "Write it now"). An answer changed later runs a change at once | 2026-11-26 |
| 32 | What does "Write it now" do with open cards? | **Marks them as guesses, with no run.** An `[!OPEN QUESTION]` callout stays in the file for the coding agent | 2026-11-26 |
| 33 | Is the contradiction check run again after its issues are fixed? | **No.** Mel's own checks by ID run again for free after every change; contradictions are looked for once, after the last file. "Check again" runs it on request | 2026-11-26 |
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
| 29 | Invariant "never change an approved file without a user action" once approval is gone | **"Never change a Ready file without a user action"**: a card answer, Tell Mel, Remove, Update or Rewrite. "Never overwrite a user's edit" stays | CLAUDE.md and DESIGN.md state the old wording |
| 34 | What moves a spec to Building and Done in the sidebar? | **The user.** "Build with Claude Code" moves it to Building; "Mark as Done" (Ready, or the row's menu) moves it to Done. Mel doesn't watch the coding agent, so "Task 3 of 7" and "Merged yesterday" aren't shown, and Ready's "What happens next" has two lines | The canvas draws progress Mel can't see without tracking the agent's work |
| 35 | Which repos does Start list? | **The 5 most recently edited** in `~/Developer`; any other folder is dropped on the window or added from the sidebar's project menu | A long list pushes Start off the screen |
| 30 | Cheaper model for small runs (intake, impact, patches)? | **Not yet.** Measure with the token readout first; then decide per run kind | Lower usage, but a quality risk the user should judge |
| 16 | Apple Developer account (for Developer ID + notarization) available? | **Yes**: Team ID `SGWP227GBQ` ("Developer ID Application: Kaan Firat" in the login keychain); notarytool keychain profile `mel-notary` | Without it the DMG triggers Gatekeeper warnings |
