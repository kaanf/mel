#!/bin/sh
# Stands in for `claude` in AgentRunner tests: replays a recorded stream.
# Usage: fake-claude.sh <fixture.jsonl> [hang | exit <code>]
# hang: print the file, then wait for a signal (one process, so signals act at once).
cat > /dev/null
case "$2" in
  hang) exec tail -f "$1" ;;
  exit) echo "fake failure" >&2; exit "$3" ;;
  *) exec cat "$1" ;;
esac
