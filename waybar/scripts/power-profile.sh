#!/bin/bash
current=$(powerprofilesctl get 2>/dev/null)

choice=$(printf "performance\nbalanced\npower-saver" \
    | rofi -dmenu \
        -p "󱐋 Power profile" \
        -mesg "Active: $current" \
        -theme-str 'window { width: 260px; }')

[ -n "$choice" ] && powerprofilesctl set "$choice"
