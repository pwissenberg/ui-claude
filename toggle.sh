#!/usr/bin/env bash
# Toggles the companion window without a key press, via its URL scheme.
# Useful for verification, and for binding from Raycast / Shortcuts / Alfred.
set -euo pipefail
open -g "claudecompanion://toggle"
echo "toggle sent"
