#!/bin/bash
# AD FINEM Stream Kit - installer for macOS. Double-click this file.
# First time macOS blocks it: right-click > Open > Open.
cd "$(dirname "$0")" || exit 1
if ! /usr/bin/xcrun --find python3 >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is needed. macOS will now offer to install the Command Line Tools - click Install,"
  echo "wait until it's done, then double-click INSTALL-mac.command again."
  xcode-select --install 2>/dev/null
  read -n 1 -s -r -p "Press any key to close."; exit 1
fi
python3 _system/install_linux.py "$@"
echo; read -n 1 -s -r -p "Press any key to close."
