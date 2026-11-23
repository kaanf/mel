# Architecture

## Modules

- TimerCore — Sources/TimerCore: adds `BreakPlanner.nextBreak(focusCountToday:settings:) -> Countdown.Kind` and `GoalProgress(done:goal:)` with its `line` text. Pure, no clock.
- SessionStore — Sources/SessionStore: adds `Settings` (goal, focus, short and long break minutes) and `SettingsLoader.load(from:)`, which reads `settings.json` from the folder it is given and falls back to defaults per key.
- FocusTimer — Sources/FocusTimer: `start` runs focus, saves it, asks `BreakPlanner` for the break, runs and saves the break. `log` prints today's sessions and `GoalProgress.line`.

## Data

- Day files are unchanged: `[Session]` per `YYYY-MM-DD.json`. Breaks are saved with kind `shortBreak` or `longBreak`.
- `Settings` is a `Codable`, `Sendable` struct. All keys optional on disk.

## Decisions

- Break kind is derived from today's saved focus sessions, so no extra state file is needed.
- Settings are read once at launch; the app never writes the settings file.
