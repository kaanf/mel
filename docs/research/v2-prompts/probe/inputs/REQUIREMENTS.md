# Requirements

This spec adds automatic short and long breaks after each focus session. It also adds a daily goal, counted in focus sessions, which `focus log` shows progress against. It builds on the current `start` / `log` commands, the `Countdown.Kind` cases that already exist (`focus`, `shortBreak`, `longBreak`), and the store that keeps one JSON file per day.


## 1. Automatic break after a focus session

P1 · MVP

As a person using FocusTimer, I want a break to start on its own when a focus session ends, so that I rest without having to remember to start a timer.

Source: Answer "How should a break start…" → Automatic.

- 1.1 WHEN a focus session finishes, THE APP SHALL save the focus session before the break starts.
- 1.2 WHEN a focus session finishes, THE APP SHALL start a break countdown right away, with no further input from the user.
- 1.3 WHEN a break starts, THE APP SHALL print one line that names the break kind (`short break` or `long break`) and its length in minutes.
- 1.4 WHEN a break countdown finishes, THE APP SHALL save it as a `Session` with kind `shortBreak` or `longBreak`, using the break's start and end times.
- 1.5 WHEN a break countdown finishes, THE APP SHALL print `Break over.` and exit with status 0.
- 1.6 WHEN no break length is configured, THE APP SHALL use 5 minutes for a short break and 15 minutes for a long break.
- 1.7 WHEN the process is stopped during a break, THE APP SHALL keep the focus session that was already saved and SHALL NOT save the unfinished break.

> [!ASSUMPTION]
> The default lengths are 5 minutes (short) and 15 minutes (long), the usual Pomodoro values. The process ends after one focus session and its break, so `start` does not loop into another focus session.

> [!ASSUMPTION]
> Breaks are saved to the day file like focus sessions. This answer was skipped, but story 4 and the long-break count need breaks to be told apart from focus sessions.

## 2. Long break every 4th focus session of the day

P1 · MVP

As a person following the Pomodoro method, I want a longer break after every fourth focus session, so that I recover properly over a working day.

Source: Answer "…how should the app know when a long break is due?" → Counted per day, long break every 4th focus session. Also feedback: "After 4 focus sessions I want a longer break."

- 2.1 WHEN a focus session finishes AND the number of finished focus sessions saved for that day (including this one) is a multiple of 4, THE APP SHALL start a long break.
- 2.2 WHEN a focus session finishes AND the number of finished focus sessions saved for that day (including this one) is not a multiple of 4, THE APP SHALL start a short break.
- 2.3 WHEN counting focus sessions for the day, THE APP SHALL ignore sessions of kind `shortBreak` and `longBreak`.
- 2.4 WHEN a new day starts, THE APP SHALL begin the count from zero, so the first focus session of the day is followed by a short break.
- 2.5 WHEN choosing the break kind, THE APP SHALL use a pure function in a library target that takes the day's focus count and returns `shortBreak` or `longBreak`, without reading the clock or the disk.

> [!ASSUMPTION]
> A session belongs to the day it **started** on, the same rule `Store` already uses to pick a file.

## 3. Daily goal with a default

P1 · MVP

As a person who "never knows when to stop", I want a daily goal of focus sessions, so that I have a clear target for the day.

Source: The idea (daily goal). Answer "Where does the daily goal come from?" → You decide. Also feedback: "A goal like 8 sessions a day would help."

- 3.1 WHEN no goal is configured, THE APP SHALL use a daily goal of 8 focus sessions.
- 3.2 WHEN a valid goal is configured (story 5), THE APP SHALL use the configured goal instead of the default.
- 3.3 THE APP SHALL count only finished focus sessions toward the goal.

## 4. Goal progress in `focus log`

P1 · MVP

As a person using FocusTimer, I want `focus log` to show how far I am toward today's goal, so that I know at a glance how much is left.

Source: The idea ("a daily goal that `focus log` shows progress against"). The format answer was skipped, so the format below is a proposal.

- 4.1 WHEN the user runs `log`, THE APP SHALL print one line per saved session for today, focus and breaks alike, showing the kind and the start time, in start-time order.
- 4.2 WHEN the user runs `log`, THE APP SHALL print a last line in the form `Goal: <done>/<goal> focus sessions`.
- 4.3 WHEN no sessions are saved for today, THE APP SHALL print only the line `Goal: 0/<goal> focus sessions`.
- 4.4 WHEN the number of finished focus sessions for today is equal to or greater than the goal, THE APP SHALL add ` — goal reached` to the end of the goal line.
- 4.5 WHEN the done count is greater than the goal, THE APP SHALL show the real count (for example `Goal: 9/8 focus sessions — goal reached`) and SHALL NOT cap it at the goal.
- 4.6 WHEN working out progress, THE APP SHALL use a pure function in a library target that takes the day's sessions and the goal, and returns the done count and whether the goal is reached.

> [!ASSUMPTION]
> The goal line format is `Goal: <done>/<goal> focus sessions`, plus ` — goal reached` once the goal is met. You skipped the question about how progress should look.

<!-- MVP line -->

## 5. Configure the goal and lengths with a settings file

P2

As a person whose work rhythm is different from the defaults, I want to set my daily goal and the focus and break lengths, so that the timer fits how I work.

Source: Answer "Where does the daily goal (and the break lengths) come from?" → You decide. The product notes that "the 25-minute length is fixed in code".

- 5.1 WHEN a file `config.json` is present in the FocusTimer Application Support folder, THE APP SHALL read the daily goal, focus length, short-break length and long-break length from it.
- 5.2 WHEN `config.json` is missing, THE APP SHALL use the defaults: goal 8, focus 25 minutes, short break 5 minutes, long break 15 minutes.
- 5.3 WHEN `config.json` leaves out a key, THE APP SHALL use the default for that key and SHALL use the values of the keys that are present.
- 5.4 WHEN `config.json` cannot be decoded as JSON, THE APP SHALL print an error message naming the file to standard error, exit with a non-zero status, and SHALL NOT start a countdown.
- 5.5 WHEN a configured goal is less than 1, or a configured length is less than 1 minute, THE APP SHALL print an error naming the invalid key to standard error, exit with a non-zero status, and SHALL NOT start a countdown.
- 5.6 THE APP SHALL never create or change `config.json`. The user edits it by hand.
- 5.7 WHEN loading settings, THE library code SHALL take the folder or file URL from the caller. Only `main.swift` uses the real Application Support path.

> [!ASSUMPTION]
> A JSON file next to the session files is enough, rather than command-line flags or environment variables. It needs no new dependencies and keeps `main.swift` thin. The keys are proposed as `dailyGoal` (integer), and `focusMinutes`, `shortBreakMinutes` and `longBreakMinutes` (integers, whole minutes).

## 6. Goal-reached message after a focus session

P3

As a person working toward the goal, I want to be told when a focus session reaches today's goal, so that I know I can stop.

Source: Feedback: "I never know when to stop."

- 6.1 WHEN a focus session finishes AND it brings today's finished focus count exactly up to the goal, THE APP SHALL print `Daily goal reached (<goal>/<goal>).` before the break starts.
- 6.2 WHEN a focus session finishes AND today's finished focus count is still below the goal, THE APP SHALL print `<done>/<goal> focus sessions today.` before the break starts.


## Quality requirements

- Q1 The logic that picks the break kind, works out goal progress, and decodes or validates settings lives in library targets (TimerCore or SessionStore). `main.swift` contains only argument parsing, the `sleep` loop, and printing.
- Q2 TimerCore functions added for this feature take the current time or counts as parameters. They never read the clock, sleep, or touch the file system.
- Q3 Every write to a day file uses `.write(to:options: .atomic)`. No file is changed in place.
- Q4 Day files written before this feature (holding only `focus` sessions) still load and are counted correctly, with no migration step.
- Q5 Any new public model type (for example a settings type) is a `Sendable` value type, and is `Codable` if it is read from or written to disk.
- Q6 The package builds with `swift build` under Swift 6 strict concurrency, with no new warnings and no third-party packages.
- Q7 Each new library behavior has at least one Swift Testing `@Test` that uses fixed dates. This includes break-kind selection, goal progress, settings decoding and validation, and day counting. SessionStore gets its first test target.
- Q8 The app makes no network calls. All data stays in the FocusTimer Application Support folder.


## Edge cases

**Story 1: automatic break**
- The user presses Ctrl-C during the focus session. Nothing is saved and no break starts, as today.
- The user presses Ctrl-C during the break. The focus session stays saved and the break is not saved (1.7).
- Saving the focus session fails (for example, the disk is full or the folder is missing). The app prints the error to standard error, exits with a non-zero status, and does not start the break.
- The Mac sleeps during a break. When it wakes, the break counts as finished if its wall-clock length has passed, because `Countdown` compares against `Date`.

**Story 2: long break every 4th**
- The 4th, 8th and 12th focus sessions of a day are each followed by a long break. The 5th is followed by a short break.
- A focus session starts at 23:50 and ends at 00:15. It counts toward the day it started on, and its break follows that day's count. The break itself is saved to the day it starts on (the new day).
- Two `focus start` processes run at the same time in two terminals. Both read the count before either saves, so they could pick the same break kind or lose an append. This is treated as unsupported (see the open question below).
- The day file contains only break sessions (for example, focus sessions were removed by hand). The count is 0 and the next focus session gets a short break.

**Story 3: daily goal**
- The goal is reached partway through the day and the user keeps going. Counting continues past the goal.
- The settings file sets a goal of 0 or a negative number. This is rejected under 5.5 rather than treated as "no goal".

**Story 4: goal progress in log**
- No day file exists for today. The output is `Goal: 0/8 focus sessions`.
- Today's day file is corrupt or not valid JSON. `log` prints an error naming the file to standard error and exits with a non-zero status, instead of crashing with an uncaught error.
- The done count equals the goal exactly. The line ends with ` — goal reached`.
- The done count is above the goal. The real number is shown (4.5).
- `log` runs just after midnight. It shows only the new day's sessions, so a focus session that started before midnight is not included.


> [!ASSUMPTION]
> "Day" means the user's **local** calendar day. Today `Store` names files with `.iso8601` formatting, which defaults to UTC. So outside UTC, sessions near midnight land in the "wrong" day file, and the per-day count for long breaks and the goal would be off. This spec assumes the day key changes to local time. If it does, existing files near midnight may sit under a different date.

> [!ASSUMPTION]
> Only finished focus sessions count toward the goal and the long-break cycle. Saving sessions that were stopped early is still out of scope.

> [!ASSUMPTION]
> The `focus` vs `FocusTimer` executable name mismatch is out of scope. Criteria refer to the `start` and `log` subcommands, not the binary name.

> [!OPEN QUESTION]
> Should the user be able to skip a break or end the day after a focus session, for example with a `--no-break` flag or by stopping during the break? Right now, stopping during the break is the only way out, and that break is not recorded.

> [!OPEN QUESTION]
> Do concurrent `focus start` processes need to be safe (locking or re-reading before appending), or is "one timer at a time" a documented limitation?


Testability check: every criterion names a trigger and an observable result: printed output, exit status, a saved `Session`, or the return value of a pure function. Criteria 2.5, 4.6 and 5.7 require the logic to sit in library targets, so it can be unit-tested with fixed dates and a temporary folder. The output criteria (1.3, 1.5, 4.x, 6.x) can be checked by running the executable with short configured lengths (story 5) against a temporary folder.
