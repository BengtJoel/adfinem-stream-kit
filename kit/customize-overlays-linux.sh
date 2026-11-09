#!/usr/bin/env bash
# AD FINEM Stream Kit - opens the overlay editor in your browser. Run:  bash customize-overlays-linux.sh
cd "$(dirname "$0")" || exit 1
exec python3 _system/editor.py "$@"
