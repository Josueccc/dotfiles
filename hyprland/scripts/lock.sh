#!/usr/bin/env bash
# lock.sh — start the quickshell lock screen (roadmap 3.3).
#
# Replaces hyprlock on the primary bind. hyprlock is still installed and still
# on a bind of its own (Super+Ctrl+Shift+L) as a fallback, because a fallback
# that cannot run while the primary is engaged is worth nothing — see the note
# at the bottom.
#
# The config lives in its own directory, so it is its own quickshell *process*:
#   quickshell -p <dir>
# and not `-c <name>`, which takes a config NAME under ~/.config/quickshell.
set -u

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/lock"

command -v quickshell >/dev/null 2>&1 || exit 0
[ -f "$CONFIG/shell.qml" ] || exit 0

# Kill a previous lock process before starting a new one.
#
# NOT `pkill -x quickshell`: the dashboard overlay is also a process called
# exactly `quickshell`, and killing it to relock would slam the overlay's state
# (and its polkit agent) out from under the session. The `-f` pattern is
# specific to this config's path.
#
# This is belt-and-braces — the process exits by itself once the session
# unlocks — but a lock process that is still alive cannot lock again ("only one
# WlSessionLock may be locked at a time"), and a stale one would otherwise make
# the next Super+Ctrl+L do nothing at all, silently.
pkill -f "quickshell -p $CONFIG" >/dev/null 2>&1
sleep 0.15

setsid quickshell -p "$CONFIG" >/dev/null 2>&1 &

# On the fallback:
#
# ext-session-lock-v1 says a conformant compositor that loses the lock surface
# without an unlock keeps the lock and paints a solid colour — the session is
# not exposed, but the machine is unusable until a TTY switch. hyprlock is
# therefore useful only when the quickshell lock is NOT currently engaged (a
# broken prompt, a UI that failed to draw) — it cannot rescue a quickshell lock
# that is already holding the session, and neither can hyprlock. That is a
# property of the protocol, not of this setup, and hyprlock has the same
# exposure if it is killed while locked.
