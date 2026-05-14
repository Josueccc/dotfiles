#!/bin/bash
# Wallpaper picker — rofi image grid → swww animated transition
# Change WALLPAPER_DIR to wherever your wallpapers live
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

if command -v swww &>/dev/null; then
    swww query &>/dev/null || swww-daemon --daemon 2>/dev/null
    swww img "$chosen" \
        --transition-type grow \
        --transition-pos center \
        --transition-fps 60 \
        --transition-duration 1.5
elif command -v waypaper &>/dev/null; then
    waypaper --wallpaper "$chosen"
else
    pkill swaybg; swaybg -i "$chosen" -m fill &
fi
