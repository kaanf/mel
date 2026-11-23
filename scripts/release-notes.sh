#!/bin/sh
# Prints the GitHub release notes for one version from CHANGELOG.md.
# Usage: scripts/release-notes.sh 0.2.1
set -eu
VERSION=$1
awk -v v="## [$VERSION]" 'index($0, v) == 1 { on = 1; next } on && /^## \[/ { exit } on' CHANGELOG.md
printf '\n---\nRequires macOS 26 and [Claude Code](https://claude.com/claude-code), signed in. Signed with Developer ID and notarized by Apple. Already on 0.2 or later? Mel › Check for Updates…\n\nFull history: [CHANGELOG.md](https://github.com/kaanf/mel/blob/main/CHANGELOG.md)\n'
