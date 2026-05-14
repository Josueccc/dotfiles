#!/bin/bash
choice=$(printf \
    "  Power off\0icon\x1fsystem-shutdown-symbolic\n  Reboot\0icon\x1fsystem-reboot-symbolic\n  Suspend\0icon\x1fsystem-suspend-symbolic" \
    | rofi -dmenu \
        -p "  Session" \
        -show-icons \
        -theme-str 'window { width: 240px; }')

case "$choice" in
    *"Power off"*) systemctl poweroff ;;
    *"Reboot"*)    systemctl reboot ;;
    *"Suspend"*)   systemctl suspend ;;
esac
