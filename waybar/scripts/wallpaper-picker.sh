#!/usr/bin/env bash
# Wallpaper picker — rofi image grid → awww transition → re-theme.
#
# Everything goes through waypaper on purpose. It owns the awww backend: it
# launches awww-daemon, kills whatever painted the background before (swaybg,
# hyprpaper, swww), builds the transition from the swww_transition_* keys in
# ~/.config/waypaper/config.ini, and fires `post_command` — which is what
# re-themes the desktop through wallust/apply-theme.sh. Do not bypass it with a
# bare `awww img`: nothing would re-theme afterwards.
#
# The awww/swaybg branches below only run on machines without waypaper, so they
# have to invoke apply-theme.sh themselves.
#
# Change WALLPAPER_DIR to wherever your wallpapers live.
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers/}"

chosen=$(find "$WALLPAPER_DIR" -maxdepth 3 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o \
        -iname "*.png" -o -iname "*.webp"  -o \
        -iname "*.gif" \) \
    | sort \
    | while IFS= read -r img; do
        # Pass full path as both the text label and the icon;
        # element-text is hidden in the theme-str below, so only
        # the image thumbnail is visible.
        printf '%s\0icon\x1f%s\n' "$img" "$img"
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

[ -z "$chosen" ] && exit 0

# Same transition as waypaper/config.ini, in case we have to drive awww here.
transition=(
    --transition-type wave
    --transition-angle 30
    --transition-fps 60
    --transition-duration 1.2
    --transition-step 20
)

if command -v waypaper >/dev/null 2>&1; then
    waypaper --wallpaper "$chosen"
    exit 0
fi

if command -v awww >/dev/null 2>&1; then
    awww query >/dev/null 2>&1 || {
        pkill -x swaybg >/dev/null 2>&1
        setsid awww-daemon >/dev/null 2>&1 &
        sleep 0.4
    }
    awww img "$chosen" "${transition[@]}"
    "$HOME/.config/wallust/apply-theme.sh" "$chosen"
    exit 0
fi

if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg >/dev/null 2>&1
    swaybg -i "$chosen" -m fill &
    "$HOME/.config/wallust/apply-theme.sh" "$chosen"
fi
