#!/usr/bin/env bash
# toggle-kb-layout.sh — switch to the next configured keyboard layout.
# Bound to Super+space in hyprland.lua.
#
# Why this is a script and not the obvious keybind: the obvious one was
# `hyprctl dispatch switchxkblayout all next`, which is a *hard error* on this
# machine. Its hyprctl is the Lua build, so dispatch arguments are parsed as Lua
# — `hl.dispatch(switchxkblayout all next)` → "')' expected near 'all'" — and the
# key did nothing at all. The Lua API has a switchxkblayout dispatcher, but it
# cannot be driven blind from a shell: every dispatcher constructor returns "ok",
# including one named `totally_bogus_name`, so a green result proves nothing.
#
# What does work is rewriting the layout list. `input:kb_layout` and
# `input:kb_variant` are *parallel* lists, so both have to move together or the
# "intl" variant lands on the Spanish layout. Rotating both flips the live keymap
# between "English (US, intl., with dead keys)" and "Spanish (Latin American)",
# and rotating back restores it.
set -u

command -v hyprctl >/dev/null 2>&1 || exit 0

# A classic (non-Lua) hyprctl has the real dispatcher and no eval subcommand, so
# use it there and keep this config portable to a stock Hyprland.
if ! hyprctl --help 2>&1 | grep -q 'eval'; then
    hyprctl dispatch switchxkblayout all next >/dev/null 2>&1 || true
    exit 0
fi

# hyprctl getoption prints "str: us, latam" — the value is everything after "str: ".
get() { hyprctl getoption "input:$1" 2>/dev/null | sed -n 's/^str: //p' | head -1; }

# Moves the first entry to the end, normalising the separators. Trimming matters:
# without it the list picks up a space per press (" us,  latam") and slowly fills
# with whitespace. A single entry is returned unchanged, and a trailing comma
# ("intl,") correctly rotates to (", intl") — the empty variant belongs to the
# layout that has none.
rotate() {
    if [ "$1" = "${1%%,*}" ]; then
        printf '%s' "$1"
        return
    fi

    local rest="${1#*,}" first="${1%%,*}"
    rest="${rest#"${rest%%[![:space:]]*}"}"   # drop leading space
    first="${first%"${first##*[![:space:]]}"}"  # drop trailing space
    printf '%s, %s' "$rest" "$first"
}

layouts="$(get kb_layout)"
[ -n "$layouts" ] || exit 0

variants="$(get kb_variant)"
next_layouts="$(rotate "$layouts")"
[ -n "$variants" ] && next_variants="$(rotate "$variants")"

# Both values are interpolated into a Lua chunk. They only ever contain xkb
# identifiers and commas, but they are quoted anyway: a syntax error here would be
# silent, which is the failure mode this whole script exists to avoid.
hyprctl eval "hl.config({input={kb_layout=\"$next_layouts\", kb_variant=\"$next_variants\"}})" \
    >/dev/null 2>&1 || exit 0

# Nothing on screen shows which layout is active, so say so.
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Keyboard" -i input-keyboard "Layout: ${next_layouts%%,*}" >/dev/null 2>&1 || true
fi
