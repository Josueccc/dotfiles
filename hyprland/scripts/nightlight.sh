#!/usr/bin/env bash
# nightlight.sh — toggle a manual night-light override on top of hyprsunset's
# time-based profiles (hyprland/hyprsunset.conf).
#
#   nightlight.sh        toggle 3800K ↔ back to the scheduled profile
#   nightlight.sh 4500   toggle to a specific temperature instead
set -u

command -v hyprctl >/dev/null 2>&1 || exit 0

state="${XDG_RUNTIME_DIR:-/tmp}/nightlight-manual"
temp="${1:-3800}"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Night light" -i weather-night "Night light" "$1" >/dev/null 2>&1
}

if [ -f "$state" ]; then
    rm -f "$state"
    hyprctl hyprsunset reset >/dev/null
    notify "Off — back to the scheduled profile"
else
    : > "$state"
    hyprctl hyprsunset temperature "$temp" >/dev/null
    notify "On — ${temp}K"
fi
