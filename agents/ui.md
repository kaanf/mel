# Agent: ui

You build every screen of Mel in SwiftUI, following the macOS 26 HIG, and later bind them to `AppState` / `SpecSession`.

Read first: `CLAUDE.md`, `agents/README.md`, `agents/CONTRACTS.md`, `docs/UI.md` (your main spec), `docs/REQUIREMENTS.md`, `docs/PRODUCT.md`. Target design (v2): `docs/design/v2/` + `docs/V2.md`, built pixel-exact (light mode, real macOS window).

## You own

- `Mel/App/` (from Wave 1; core leaves a placeholder in Wave 0)
- `Mel/Views/` (all screens, `Components/`, `Preview/` preview data)

Layer rule (CONTRACTS.md › Layers and dependencies): files in `Mel/Views/` import only `SwiftUI`, `MelSpec` and `UniformTypeIdentifiers` (file pickers use SwiftUI `fileImporter`). Every action a view triggers (copy, Show in Finder, Terminal, Sign In) is a method on `AppState`/`SpecSession`; never call `MelSystem`, `MelAgent` or `MelStorage` from a view. `MelApp` is the composition root.
- Asset catalog (app icon, accent color)
- `agents/status/ui.md`

## Wave 0 · Foundation

You run in parallel with core, before the Xcode project exists. Build the shared components that don't need model types, in `Mel/Views/Components/`, type-checked with `xcrun swiftc -typecheck -swift-version 6 -target arm64-apple-macos26.0 <files>`:

- `StatusBadge` (Ready / Checking with pulse / Needs you / Stopped / Locked / Approved; SF Symbols + semantic colors; pulse off with Reduce Motion)
- `StageStepper` (Idea › Questions › Draft › Review, current step highlighted)
- `RadioRow` (label, note, "Suggested" badge, key hint, selected state; a real `Button` with accessibility traits)
- `CalloutView` (assumption: text + Change… / Confirm)
- `KeyHint` (the small key cap, e.g. "1", "↩")
- `ProgressStrip` (thin bar under the toolbar)

Done when: they type-check. Each gets `#Preview`s once the project exists. Commit, push, update status, stop.

## Wave 1 · Parts

Rebase on `main` first.

- **0.2** `App/MelApp.swift`: `WindowGroup` with `NavigationSplitView` + inspector toggle, `Window` "Welcome", `Settings` scene with General / Agents / Specs / Advanced tabs, commands (⌘N, ⌘↩, ⌥⌘I).
- **3.1–3.10** every screen in UI.md (MVP version), each with `#Preview`s for every state, using `AppState.preview` / `SpecSession.preview` and your own data in `Views/Preview/`:
  Welcome · Settings › Agents · Sidebar · New Spec sheet · Discovery · Markdown block renderer (`LazyVStack` over `MarkdownParser.blocks`) · Drafting · Review (Preview / Edit Markdown, Before you approve, Approve disabled while assumptions remain) · Failure sheet · Spec ready sheet.
- Views call `SpecSession` / `AppState` methods; they never touch files, processes or the agent directly.

Done when: every screen and state has a preview that renders, build green.

## Wave 2 · Wiring

- Bind all screens to the live `AppState` / `SpecSession` (core makes them real in this wave).
- Keyboard: 1–4 and ↩ in Discovery, ⌘↩ approve, ⌘N, ⌥⌘I.
- Keep Mine / Use File prompt on external edits; missing-folder rows with Locate… / Remove from list.
- Handoff sheet actions call `SpecSession` (`openStartCommandInTerminal`, `showInFinder`, `finish(commitToGit:)`); core wires them to platform's `SystemActions` / `Git`. Views never import MelSystem.

## Wave 3 · Ship

- **5.2** accessibility pass: VoiceOver labels and order, full keyboard use, Dark Mode, Increase Contrast, Reduce Motion.
- App icon.

## Don't

- Don't edit `MelKit/Sources/MelSpec/`, `MelKit/Sources/MelStorage/`, `Mel/Session/`, `MelKit/Sources/MelAgent/`, `MelKit/Sources/MelSystem/`, or project settings.
- No custom colors, fonts or shadows from the HTML canvas. No emoji.
- No logic in views beyond presentation; ask core (via your status file) for anything missing on `SpecSession`.
