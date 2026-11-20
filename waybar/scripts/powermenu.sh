#!/bin/bash
choice=$(printf \
    "  Exit session\0icon\x1fsystem-log-out-symbolic\n  Power off\0icon\x1fsystem-shutdown-symbolic\n  Reboot\0icon\x1fsystem-reboot-symbolic\n  Suspend\0icon\x1fsystem-suspend-symbolic" \
    | rofi -dmenu \
        -p "  Session" \
        -show-icons \
        -theme-str 'window { width: 240px; }')

case "$choice" in
    *"Exit session"*) command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl eval "hl.dispatch(hl.dsp.exit())" || hyprctl dispatch exit ;;
    *"Power off"*) systemctl poweroff ;;
    *"Reboot"*)    systemctl reboot ;;
    *"Suspend"*)   systemctl suspend ;;
esac
