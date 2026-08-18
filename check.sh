#!/usr/bin/env bash
# Inspects the live page and prints the result. Run this WHILE the window looks
# wrong - it reports whether the composer is actually laid out, which tells you
# if the problem is the DOM or just a missing repaint.
set -euo pipefail
open -g "claudecompanion://check"
sleep 1
grep -E "health check" ~/Library/Logs/ClaudeCompanion.log | tail -2
