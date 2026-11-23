# Clean-install test (5.4)

Run before each release on a **new macOS 26 standard user account**, using the notarized DMG from `scripts/release.sh`. It checks what only a real install shows: Gatekeeper, finding `claude` when Mel starts from the Dock (REQ 1.2), and the first-run flow (REQ 1, 5.8, 8).

Write the result of each step in the table at the end. Any ✗ blocks the release.

## 0. Before you start (your normal account)

1. Build: `TEAM_ID=SGWP227GBQ scripts/release.sh`. It ends with `✓ .build/release/Mel-<version>.dmg`.
2. Check the DMG:
   ```sh
   xcrun stapler validate .build/release/Mel-*.dmg            # "The validate action worked!"
   spctl -a -t open --context context:primary-signature -vv .build/release/Mel-*.dmg   # accepted, source=Notarized Developer ID
   ```
3. Put the DMG somewhere the test account can **download** it (a private link, AirDrop). Copying it through `/Users/Shared` skips the quarantine flag, so Gatekeeper wouldn't run.
4. System Settings › Users & Groups › Add User: a **Standard** account, e.g. "Mel Test". Log out, then log in as that user.

## 1. Gatekeeper

1. Download the DMG. In Terminal: `xattr -p com.apple.quarantine ~/Downloads/Mel-*.dmg` prints a value (the file is quarantined).
2. Open the DMG: it mounts without a warning and shows Mel and an Applications link.
3. Drag Mel to Applications, eject the DMG, open Mel from Applications.
   - Expected: only "Mel is an app downloaded from the Internet… Open". **Not** "can't be verified" or "Move to Trash".
4. Quit Mel. Turn off Wi-Fi, open Mel again: it opens (the notarization ticket is stapled). Turn Wi-Fi back on.

## 2. First run without Claude Code

Claude Code isn't installed for this user yet.

1. Open Mel → Welcome window. The Claude Code row shows Checking, then **Not found** with "Choose File…" (REQ 1.1, 1.3, 1.8).
2. "Continue Without Agent" → main window; New Spec is disabled and says why, with a way to fix it (REQ 1.9).

## 3. Install and sign in

1. In Terminal, install Claude Code the way its docs describe. Don't sign in yet. `which claude` shows its path (typically `~/.local/bin/claude` or `/opt/homebrew/bin/claude`).
2. In Mel: Welcome or Settings › Agents → "Scan Again". The row shows **Not signed in** and "Sign In…" (REQ 1.5).
3. Click "Sign In…": Terminal opens and runs `'<path>/claude' auth login` (REQ 1.6). Sign in with the **Claude subscription** account, not an API key or Console account.
4. Switch back to Mel: the row turns **Ready** with the path and version, without pressing anything (REQ 1.4, 1.6).

## 4. PATH when launched from the Dock

1. Quit Mel (⌘Q). Drag Mel to the Dock, then open it from the Dock: still **Ready** with the same path.
2. Custom PATH (checks that the login shell `PATH` is read, not just the default folders):
   ```sh
   mkdir -p ~/tools/bin && mv "$(which claude)" ~/tools/bin/
   echo 'export PATH="$HOME/tools/bin:$PATH"' >> ~/.zshrc
   ```
   Quit Mel, open it from the Dock: **Ready**, path `~/tools/bin/claude`.
3. Extra search path: delete the `export` line from `~/.zshrc`, quit Mel, open it from the Dock: **Not found**. Settings › Agents › add `~/tools/bin` → Scan Now → **Ready** (REQ 2.4). Quit and reopen: still **Ready** (the path is saved).
4. Put things back: `mv ~/tools/bin/claude` to where it came from (or reinstall).

## 5. First spec, end to end

1. New Spec: a short idea, parent folder `~/Developer`. The sheet shows `~/Developer/<slug>/specs`.
2. Discovery: answer a few questions, including one "You decide". Activity lines appear while Claude reads.
3. Drafting: as soon as Product starts drafting, switch to another app.
   - First run only: macOS asks whether Mel may send notifications → Allow.
   - A notification arrives when the file is ready to review (REQ 5.8). With Mel in front, no banner shows.
4. Review and approve all four files. Edit one by hand first and check the edit survives.
5. Spec ready (REQ 8):
   - Copy → the pasted command is `claude "Read specs/ and implement TASKS.md, task 1"`.
   - Open in Terminal → Terminal opens **in the project folder** with the command typed and running.
   - Commit the spec to Git (on a fresh account, `/usr/bin/git` may need the Command Line Tools first; without them the checkbox is hidden): first it asks to create a repository. Then `git -C ~/Developer/<slug> log --stat` shows one commit with the four files and **no** `specs/.mel/`.
   - Show in Finder → Finder shows the `specs` folder.
6. Quit and reopen Mel: the library, selection and window come back (REQ 9.2).

## 6. Subscription only

1. Add `export ANTHROPIC_API_KEY=sk-test` to `~/.zshrc`, quit Mel, open it from the Dock, start a new spec. Discovery still runs on the subscription: Mel doesn't pass that variable to Claude Code.
2. Remove the line again.

## 7. Clean up

Log out, then delete the test user in System Settings › Users & Groups (delete the home folder too).

## Results

| Step | Result | Notes |
|---|---|---|
| 0 DMG stapled, `spctl` accepted | | |
| 1 Gatekeeper: opens with no warnings beyond "downloaded from the Internet"; opens offline | | |
| 2 Not found → Continue Without Agent, New Spec disabled | | |
| 3 Not signed in → Sign In… → Ready on return | | |
| 4.1 Ready when launched from the Dock | | |
| 4.2 Custom PATH in `~/.zshrc` | | |
| 4.3 Extra search path, saved after relaunch | | |
| 5 First spec end to end, notification, handoff | | |
| 5.6 Library restored after relaunch | | |
| 6 Subscription only with an API key in the shell | | |

macOS version: ______ · Claude Code version: ______ · Mel version: ______ · Date: ______
