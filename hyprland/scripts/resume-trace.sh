#!/usr/bin/env bash
# resume-trace.sh — leave evidence of what the compositor saw around a suspend.
#
# Hyprland logs to $XDG_RUNTIME_DIR/hypr/<sig>/hyprland.log, which is tmpfs: a
# resume that ends on a black screen and a hard power-off erases the one log
# that would say why. Every failed resume on 2026-09-29 (three of three) left
# nothing behind but the kernel's side of the story. This copies the
# compositor's side into the persistent journal:
#
#   journalctl -b -1 -t resume-trace        # after the forced reboot
#
# Usage (from hypridle.conf):
#   resume-trace.sh pre    before_sleep_cmd: snapshot output state
#   resume-trace.sh post   after_sleep_cmd:  snapshot, then stream the log
#
# `post` detaches and streams hyprland.log for 3 minutes. It must never block
# after_sleep_cmd, which is also what brings the screens back.
set -u

TAG=resume-trace
log() { systemd-cat -t "$TAG" -p info; }

base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
sig=""
for dir in $(ls -1t "$base" 2>/dev/null); do
    [ -S "$base/$dir/.socket.sock" ] && { sig="$dir"; break; }
done
[ -n "$sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$sig"

snapshot() {
    {
        echo "== $1 $(date '+%F %T.%N')"
        hyprctl monitors all 2>&1 | grep -E '^Monitor|dpmsStatus|disabled|^\s+[0-9]+x[0-9]+@'
        for c in /sys/class/drm/card*-*; do
            echo "$(basename "$c") $(cat "$c/status" 2>/dev/null) dpms=$(cat "$c/dpms" 2>/dev/null)"
        done
        echo "nvidia runtime=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null)"
        echo "lock procs: $(pgrep -af 'quickshell -p' | tr '\n' ';')"
    } | log
}

case "${1:-post}" in
    pre)
        snapshot pre-sleep
        ;;
    post)
        snapshot post-resume
        [ -n "$sig" ] || exit 0
        # Detached: tail the live log into the journal, then one late snapshot
        # to show whether the outputs settled or stayed dark.
        setsid bash -c '
            timeout 180 tail -n0 -F "$1" | systemd-cat -t "$2" -p debug
        ' _ "$base/$sig/hyprland.log" "$TAG" >/dev/null 2>&1 &
        ( sleep 15; snapshot post-resume+15s ) >/dev/null 2>&1 &
        ;;
esac
exit 0
