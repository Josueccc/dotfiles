#!/usr/bin/env bash
# Wallpaper picker — Super+W. Opens the quickshell carousel
# (quickshell/wallpaper/shell.qml); a second press closes it.
#
# The picker only chooses. Setting goes through wallpaper.sh, which handles
# images AND videos and keeps the waypaper → post_command → apply-theme.sh
# chain that re-themes the desktop. See the header there.
#
# Without quickshell this falls back to the old rofi grid, now listing videos
# too (by their cached thumbnails).
set -u

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wallpaper"
WALLPAPER_SH="$HOME/.config/waybar/scripts/wallpaper.sh"

if command -v quickshell >/dev/null 2>&1 && [ -f "$CONFIG/shell.qml" ]; then
    # Toggle. -f on the config path, which is specific enough not to match the
    # dashboard (a bare `quickshell`) or the lock (…/quickshell/lock) — and not
    # this shell either, whose command line does not contain it.
    if pkill -f "quickshell -p $CONFIG" >/dev/null 2>&1; then
        exit 0
    fi
    # The carousel opens on the focused monitor; see `screen:` in shell.qml for
    # why this is passed in rather than read there.
    mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null)
    RIZZ_MONITOR="$mon" setsid quickshell -p "$CONFIG" >/dev/null 2>&1 &
    exit 0
fi

chosen=$("$WALLPAPER_SH" list \
    | while IFS=$'\t' read -r _kind path thumb; do
        printf '%s\0icon\x1f%s\n' "$path" "$thumb"
    done \
    | rofi -dmenu \
        -p "  Wallpaper" \
        -show-icons \
        -theme-str '
            window   { width: 860px; }
            listview { columns: 4; lines: 3; spacing: 8px; fixed-height: true; }
            element  { border-radius: 10px; padding: 6px; orientation: vertical; }
            element-icon { size: 9em; border-radius: 6px; }
            element-text { enabled: false; }
            element.selected.normal { background-color: @blue; }
            inputbar { margin: 0 0 8px 0; }
        ')

[ -n "$chosen" ] && exec "$WALLPAPER_SH" set "$chosen"
