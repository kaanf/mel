## 2. Long break every 3rd focus session of the day

P1 · MVP

As a person following the Pomodoro method, I want a longer break after every fourth focus session, so that I recover properly over a working day.

Source: Answer "…how should the app know when a long break is due?" → Counted per day, long break every 3rd focus session. Also feedback: "After 4 focus sessions I want a longer break."

- 2.1 WHEN a focus session finishes AND the number of finished focus sessions saved for that day (including this one) is a multiple of 3, THE APP SHALL start a long break.
- 2.2 WHEN a focus session finishes AND the number of finished focus sessions saved for that day (including this one) is not a multiple of 3, THE APP SHALL start a short break.
- 2.3 WHEN counting focus sessions for the day, THE APP SHALL ignore sessions of kind `shortBreak` and `longBreak`.
- 2.4 WHEN a new day starts, THE APP SHALL begin the count from zero, so the first focus session of the day is followed by a short break.
- 2.5 WHEN choosing the break kind, THE APP SHALL use a pure function in a library target that takes the day's focus count and returns `shortBreak` or `longBreak`, without reading the clock or the disk.

> [!ASSUMPTION]
> A session belongs to the day it **started** on, the same rule `Store` already uses to pick a file.