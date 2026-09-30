#!/bin/bash
# Cycle the power profile (roadmap 3.2).
#
# This used to be a rofi dmenu over `powerprofilesctl get|set`. The profile
# state now lives in quickshell (Services.UPower), so this only forwards a
# click: `qs ipc call power cycle`. The daemon underneath is the same one
# powerprofilesctl talks to, so nothing about the behaviour changed except
# that a battery click no longer spawns rofi.
#
# Cycling rather than opening a menu is deliberate — it is what a click on a
# battery in the bar should do. The explicit picker still exists, in the
# dashboard's SYSTEM card.
#
# Note the `power` target, not `dashboard`: a `dashboard toggle` here would
# open the full-screen overlay on every battery click.

qs ipc call power cycle >/dev/null 2>&1
