# Tasks

- [ ] 1. BreakPlanner in TimerCore
  - Priority: P1
  - Covers: 1.6, 2.1, 2.2, 2.3, 2.4, 2.5
  - Reads: Sources/TimerCore/Countdown.swift
  - Verify: `swift test --filter BreakPlannerTests`

- [ ] 2. Settings and SettingsLoader
  - Priority: P1
  - Covers: 3.1, 3.2, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7
  - Reads: Sources/SessionStore/Store.swift
  - Verify: `swift test --filter SettingsLoaderTests`

- [ ] 3. GoalProgress in TimerCore
  - Priority: P1
  - Covers: 3.3, 4.2, 4.3, 4.4, 4.5, 4.6
  - Reads: Sources/TimerCore/Countdown.swift
  - Verify: `swift test --filter GoalProgressTests`
  - Parallel with: 1, 2

- [ ] 4. Wire breaks into `start`
  - Priority: P1
  - Covers: 1.1, 1.2, 1.3, 1.4, 1.5, 1.7
  - Reads: Sources/FocusTimer/main.swift
  - Verify: `swift run FocusTimer start` with a 1-minute focus length in settings.json

- [ ] 5. Show progress in `log`
  - Priority: P1
  - Covers: 4.1
  - Reads: Sources/FocusTimer/main.swift
  - Verify: `swift run FocusTimer log`

- [ ] 6. Play a sound when a break ends
  - Priority: P2
  - Covers:
  - Reads: Sources/FocusTimer/main.swift
  - Verify: listen for the system sound after `start`
