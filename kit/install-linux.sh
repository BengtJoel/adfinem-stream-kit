#!/usr/bin/env bash
# AD FINEM Stream Kit - installer for Linux. Run:  bash install-linux.sh
cd "$(dirname "$0")" || exit 1
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is needed (it's on almost every Linux). Install it with your package manager, then run this again."
  exit 1
fi
exec python3 _system/install_linux.py "$@"
