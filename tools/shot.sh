#!/usr/bin/env bash
# Run the game on the private virtual display :99 (software OpenGL) with scripted input,
# so tests never touch the desktop you are working on. Screenshots come from the game itself.
#   tools/shot.sh "sleep:4;shot:/tmp/a.png;dclick:800,300;sleep:3;shot:/tmp/b.png;quit"
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[ -S /tmp/.X11-unix/X99 ] || "$HOME/dev/jev/jev-photos/scripts/test-display.sh" 99
save="${SAVE:-/tmp/jev-aquarium-test.json}"
DISPLAY=:99 __GLX_VENDOR_LIBRARY_NAME=mesa LIBGL_ALWAYS_SOFTWARE=1 \
  godot --path "$root" --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1600x900 \
  -- --fresh --save="$save" "--steps=$1"
