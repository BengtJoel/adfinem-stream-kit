#!/usr/bin/env bash
# AD FINEM Stream Kit - removes the AD FINEM scene collection and app-menu launcher.
# Your kit folder and settings are kept. Run:  bash uninstall-linux.sh
removed=0
for d in "${XDG_CONFIG_HOME:-$HOME/.config}/obs-studio" "$HOME/.var/app/com.obsproject.Studio/config/obs-studio" "$HOME/snap/obs-studio/current/.config/obs-studio"; do
  for f in "$d/basic/scenes/AD_FINEM.json" "$d/basic/scenes/AD_FINEM_Forever.json"; do
    if [ -f "$f" ]; then mv "$f" "$f.removed" && echo "Removed: $f (kept as .removed)"; removed=1; fi
  done
done
l="${XDG_DATA_HOME:-$HOME/.local/share}/applications/adfinem-customize-overlays.desktop"
[ -f "$l" ] && rm -f "$l" && echo "Removed the app-menu launcher."
[ $removed = 0 ] && echo "No AD FINEM scene collection found."
echo "Done. Your kit folder was kept."
