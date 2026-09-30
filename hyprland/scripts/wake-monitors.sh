#!/usr/bin/env bash
# wake-monitors.sh — turn the outputs back on after a suspend, and mean it.
#
# Wired into hypridle.conf as `after_sleep_cmd`. It replaces the bare
# `hyprctl eval "hl.dispatch(hl.dsp.dpms('on'))"` that used to be there, which
# is what left this machine sitting on two black screens after a resume.
#
# Why a script and not the one-liner (two independent ways it can silently do
# nothing — after_sleep_cmd output goes nowhere, so a failure is invisible):
#
#   1. A stale instance signature. hyprctl resolves the compositor through
#      $HYPRLAND_INSTANCE_SIGNATURE and prints "Couldn't connect to ..." when it
#      points at a dead instance, then exits without doing anything. This is not
#      hypothetical: compositor restarts leave their old signature directory
#      behind, and a long-lived shell keeps the dead one exported. So resolve the
#      signature from the filesystem here instead of trusting the environment.
#
#   2. A race with the DRM re-arm. Coming out of S3, logind runs after_sleep_cmd
#      while the outputs are still being re-armed, and the kernel re-blanks the
#      CRTCs afterwards — aquamarine's log shows exactly that dance ("Rechecking
#      CRTCs", "eDP-1 is disabled, releasing crtc 85", the slots reassigned). A
#      single dpms-on issued during that window is simply overwritten. Hence the
#      settle delay, and hence checking the result instead of assuming it.
#
# "Did it work" is `hyprctl monitors | grep dpmsStatus` (1 = on). A return code
# from hyprctl proves nothing — see CLAUDE.md.
#
# Usage: wake-monitors.sh [seconds]   (default 1.5s settle, then up to 5 attempts)
set -u

SETTLE="${1:-1.5}"
ATTEMPTS=5

command -v hyprctl >/dev/null 2>&1 || exit 0

# Point hyprctl at an instance that is actually alive. Prefer the inherited
# variable when it works — it is right in the common case — and fall back to
# scanning $XDG_RUNTIME_DIR/hypr for the newest directory that still has a
# control socket. A directory without .socket.sock is a dead compositor's
# leftover; hyprctl will happily try it and fail.
live_sig() {
    local base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" dir
    [ -d "$base" ] || return 1
    # Newest first, so a fresh instance wins over a leftover.
    for dir in $(ls -1t "$base" 2>/dev/null); do
        if [ -S "$base/$dir/.socket.sock" ]; then
            printf '%s' "$dir"
            return 0
        fi
    done
    return 1
}

if ! hyprctl monitors >/dev/null 2>&1; then
    sig="$(live_sig)" || exit 0
    [ -n "$sig" ] || exit 0
    HYPRLAND_INSTANCE_SIGNATURE="$sig"
    export HYPRLAND_INSTANCE_SIGNATURE
    hyprctl monitors >/dev/null 2>&1 || exit 0
fi

# dpms on. The hl.dispatch(...) wrapper is not optional — hl.dsp.dpms(...) on
# its own only builds a dispatcher object and blanks nothing, and it still
# returns "ok". And the argument MUST be a table: hl.dsp.dpms('on') ignores
# its string and TOGGLES every output (verified 2026-09-30: with eDP-1 off and
# HDMI-A-1 on it swapped them). { action = 'on' } really means on.
dpms_on() {
    if hyprctl --help 2>&1 | grep -q 'eval'; then
        hyprctl eval "hl.dispatch(hl.dsp.dpms({ action = 'on' }))" >/dev/null 2>&1
    else
        # A stock (non-Lua) hyprctl has the real dispatcher and no eval.
        hyprctl dispatch dpms on >/dev/null 2>&1
    fi
}

dpms_off() {
    if hyprctl --help 2>&1 | grep -q 'eval'; then
        hyprctl eval "hl.dispatch(hl.dsp.dpms({ action = 'off' }))" >/dev/null 2>&1
    else
        hyprctl dispatch dpms off >/dev/null 2>&1
    fi
}

log() { printf '%s\n' "$*" | systemd-cat -t wake-monitors -p info 2>/dev/null; }

# All outputs reporting on. Prints nothing; true when nothing needs doing.
all_on() {
    local total on
    total="$(hyprctl monitors 2>/dev/null | grep -c '^Monitor ')"
    [ "$total" -gt 0 ] || return 1
    on="$(hyprctl monitors 2>/dev/null | grep -c 'dpmsStatus: 1')"
    [ "$total" -eq "$on" ]
}

# dpmsStatus: 1 is NOT proof the output is showing anything. After a resume on
# 2026-09-29 the Samsung (HDMI-A-1, driven by the NVIDIA dGPU as a secondary
# GPU) reported dpmsStatus 1 and stayed black: aquamarine logged "Cannot
# commit when a page-flip is awaiting" — a flip completion that never arrived,
# so no frame was ever committed again. The proof is a screencopy: grim waits
# for the output's next frame, so on a stuck output it hangs forever, on a live
# one it returns in milliseconds. Only a TIMEOUT (124) counts as stuck; grim
# failing fast (e.g. screencopy refused under the lock) is not evidence.
# A dpms off/on cycle forces a fresh modeset and cleared it, verified live.
stuck_outputs() {
    command -v grim >/dev/null 2>&1 || return 0
    local m out=""
    for m in $(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}'); do
        timeout 3 grim -s 0.05 -o "$m" - >/dev/null 2>&1
        [ $? -eq 124 ] && out="$out $m"
    done
    printf '%s' "${out# }"
}

unstick() {
    local stuck
    stuck="$(stuck_outputs)"
    [ -z "$stuck" ] && return 0
    log "no frames on: $stuck; cycling dpms"
    dpms_off; sleep 1; dpms_on; sleep 1.5
    stuck="$(stuck_outputs)"
    [ -z "$stuck" ] && { log "recovered"; return 0; }
    log "still no frames on: $stuck"
    command -v notify-send >/dev/null 2>&1 && \
        notify-send -a "Hyprland" "No picture on $stuck after resume" >/dev/null 2>&1
    return 1
}

log "invoked (${WAKE_REASON:-unknown}): $(hyprctl monitors 2>/dev/null | awk '/^Monitor /{m=$2} /dpmsStatus/{printf "%s=%s ", m, $2}')"

# Nothing to switch on — the common case when this runs from an idle-resume
# rather than a real suspend. Still check the outputs are actually drawing.
if all_on; then
    unstick
    exit 0
fi

sleep "$SETTLE" 2>/dev/null || true

n=1
while [ "$n" -le "$ATTEMPTS" ]; do
    dpms_on
    # Give the compositor a moment to apply it before believing the answer.
    sleep 0.4
    all_on && { unstick; exit 0; }
    n=$(( n + 1 ))
    sleep 1
done

# Out of attempts. Say so, somewhere the user might actually see it: this runs
# from after_sleep_cmd, where stdout goes nowhere at all.
log "outputs stayed off after $ATTEMPTS attempts"
command -v notify-send >/dev/null 2>&1 && \
    notify-send -a "Hyprland" "Screens stayed off after resume" >/dev/null 2>&1

exit 0
