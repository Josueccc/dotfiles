#!/usr/bin/env bash
# cava.sh — feed waybar's custom/cava module.
#
# cava's normal terminal output can't be piped (ANSI escapes + no window size
# on a pipe), so ~/.config/cava/config runs it in raw/ascii mode: one digit
# (0-7) per bar, newline-terminated. Here we map those digits to the Unicode
# block glyphs. Colour comes from waybar's CSS (#custom-cava).
#
# Left-click / scroll are handled by the module definition in config.jsonc.
set -u

config="$HOME/.config/cava/config"
command -v cava >/dev/null 2>&1 || exit 0

# A waybar restart doesn't necessarily reap the old cava. Only ever kill one
# that was started with our config, never a cava the user runs in a terminal.
pkill -f -- "cava -p $config" >/dev/null 2>&1

glyphs=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

cava -p "$config" | while IFS= read -r line; do
    # Drop the separator and anything that isn't a level digit, so a stray
    # delimiter change shows up as clean bars instead of garbage in the bar.
    line="${line//[^0-7]/}"
    for i in "${!glyphs[@]}"; do
        line="${line//$i/${glyphs[$i]}}"
    done
    printf '%s\n' "$line"
done
