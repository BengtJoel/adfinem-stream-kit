#!/bin/bash
# AD FINEM Stream Kit - opens the overlay editor in your browser (macOS). Close this window when you're done.
cd "$(dirname "$(readlink "$0" || echo "$0")")" 2>/dev/null || cd "$(dirname "$0")" || exit 1
exec python3 _system/editor.py "$@"
