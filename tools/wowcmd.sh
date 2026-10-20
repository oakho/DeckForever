#!/bin/bash
# usage: wowcmd.sh "/cmd1" "/cmd2" ... : types each line into WoW chat, then closes Easy Controller's
# chat keyboard (its X) if it opened. Letters q/a/z/w/m can be mistyped (AZERTY): avoid them.
W=$(xdotool search --name "World of Warcraft" | head -1)
[ -n "$W" ] || { echo "no wow window"; exit 1; }
xdotool windowactivate --sync $W; sleep 0.3
for c in "$@"; do xdotool key Return; sleep 0.35; xdotool type --delay 30 "$c"; sleep 0.15; xdotool key Return; sleep 0.6; done
case "$*" in *"/reload"*) ;; *) xdotool mousemove 1070 358 click 1; sleep 0.3; xdotool mousemove 640 300;; esac
echo sent
