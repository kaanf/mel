# In-app update test (5.5, gate G5)

Proves that a Release build updates itself through Sparkle: check → download → EdDSA signature check → replace → relaunch. It runs on one Mac against a localhost feed, so it needs no GitHub release. Run it again when the Sparkle version, signing, or `release.sh` changes.

**Result 2026-11-23: ✓** (Sparkle 2.10.1, main 4e37bc9, macOS 26). Build 1000 (0.2) updated itself to 1001 (0.2.1) and relaunched from the same path.

## Isolation

- Test copies use the bundle ID `com.kaanf.mel.updatetest`. Mel keeps all its state in standard `UserDefaults`, so this copy shares nothing with `/Applications/Mel.app` or the `com.kaanf.mel` defaults. Neither is touched.
- The installed copy lives in a `mktemp -d /tmp/mel-update-test.XXXXXX` folder, never in `/Applications`.
- Release builds check automatically (`SPARKLE_AUTOMATIC_CHECKS` = YES), so the feed override is written **before** the first launch.
- Don't run `xcodebuild test` during the test. It launches a test host and can quit GUI apps mid-update.

## Steps

1. **Two builds**, Developer ID signed but not notarized: they never leave the Mac, so Gatekeeper's quarantine check doesn't apply. Build each the way `release.sh` does (archive → `-exportArchive` with `developer-id` → DMG), plus overrides:
   ```sh
   xcodebuild archive … -derivedDataPath "$W/DerivedData" \
     CURRENT_PROJECT_VERSION=1000 MARKETING_VERSION=0.2 PRODUCT_BUNDLE_IDENTIFIER=com.kaanf.mel.updatetest \
     CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=SGWP227GBQ
   ```
   Then build again with `CURRENT_PROJECT_VERSION=1001 MARKETING_VERSION=0.2.1`. Sparkle compares `CFBundleVersion`, so 1001 > 1000 is the update.
2. **Install N**: `ditto "$W/1000/Mel.app" "$W/install/Mel.app"`.
3. **Feed**: copy `Mel-0.2.1.dmg` into `$W/feed/`. Write `$W/feed/appcast.xml` with the same item `release.sh` writes, using enclosure URL `http://127.0.0.1:8765/Mel-0.2.1.dmg` and the output of `.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update` on that DMG. Serve it with `cd "$W/feed" && python3 -m http.server 8765 --bind 127.0.0.1`. ATS exempts localhost, so plain HTTP works. Sparkle logs a "may need to change to use HTTPS" note.
4. **Override the feed for the test bundle only**, before the first launch:
   `defaults write com.kaanf.mel.updatetest SUFeedURL http://127.0.0.1:8765/appcast.xml`. Sparkle prefers a feed URL in user defaults over Info.plist and logs a warning saying so. That warning is expected here.
5. **Logs** (optional): `/usr/bin/log stream --style compact --predicate 'subsystem BEGINSWITH "org.sparkle-project" OR process == "Autoupdate" OR process == "Updater"'`. Use the full path: zsh has a `log` builtin.
6. **Drive it**: `open -n "$W/install/Mel.app"` (by path, so `/Applications/Mel.app` can't be picked). Then Mel › Check for Updates… → **Install Update** → **Install and Relaunch**. These can be clicked with `osascript` System Events, using the process's unix ID.
7. **Clean up**: quit the test copy, stop the server, `defaults delete com.kaanf.mel.updatetest`. The `/tmp` folder can be deleted by hand.

## What happened

| Step | Evidence | |
|---|---|---|
| Feed read from override | http.server: `GET /appcast.xml 200`; alert "Software Update" offered 0.2.1 | ✓ |
| Download | `GET /Mel-0.2.1.dmg 200`; window "Ready to Install" | ✓ |
| Signature check | Autoupdate: `OK: EdDSA signature is correct for update` | ✓ |
| Replace | `$W/install/Mel.app` now CFBundleVersion 1001 / 0.2.1; `codesign --verify --deep --strict` ok, TeamIdentifier SGWP227GBQ | ✓ |
| Relaunch | old PID quit within 1 s; new PID started from the same path about 15 s later | ✓ |
| Isolation | `/Applications/Mel.app` unchanged (build 1, mtime before the test); `com.kaanf.mel` defaults untouched | ✓ |

Benign log lines: `bookmark data for update download is stale.. but still continuing` (Sparkle continues) and a sqlite note about `/private/var/db/DetachedSignatures`.

Not covered: a notarized, quarantined download from GitHub (the first real in-app update after v0.2 covers it), and a negative test with a tampered signature.
