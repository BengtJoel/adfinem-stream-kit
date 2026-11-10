#!/bin/bash
# AD FINEM Stream Kit - removes the AD FINEM scene collections from OBS (macOS). Your kit folder is kept.
d="$HOME/Library/Application Support/obs-studio/basic/scenes"
removed=0
for f in "$d/AD_FINEM.json" "$d/AD_FINEM_Forever.json"; do
  if [ -f "$f" ]; then mv "$f" "$f.removed" && echo "Removed: $f (kept as .removed)"; removed=1; fi
done
l="$HOME/Desktop/AD FINEM - Customize overlays.command"
[ -L "$l" ] && rm -f "$l" && echo "Removed the Desktop shortcut."
[ $removed = 0 ] && echo "No AD FINEM scene collection found."
echo "Done. Your kit folder was kept."
read -n 1 -s -r -p "Press any key to close."
