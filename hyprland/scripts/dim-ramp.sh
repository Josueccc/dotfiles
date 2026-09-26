#!/usr/bin/env bash
# dim-ramp.sh — fade the panel down to a target brightness instead of snapping to
# it, and put it back when the user comes back. Driven by hyprland/hypridle.conf.
#
#   dim-ramp.sh dim [seconds] [percent]   fade down (default: 45s to 10%)
#   dim-ramp.sh wake                       cancel the fade, restore the brightness
#   dim-ramp.sh cancel                     stop the fade, leave brightness as-is
#
# Why this is a script and not a `brightnessctl set` in hypridle.conf:
#
#   - A single `set` is a step change. Five minutes into an idle stretch a jump
#     reads as the machine misbehaving rather than as the screen dimming.
#   - `brightnessctl set 10` is a *raw* sysfs value, not 10%. This panel's max is
#     65535, so the dim step was asking for 0.015% — effectively black — while
#     the comment beside it claimed it was "dimming the panel". The percentage
#     here is a real percentage, computed against the device max, so the config
#     and the effect finally say the same thing.
#
# Traps this script is shaped around:
#
#   - `pkill -f dim-ramp` matches the *calling shell*, because the pattern occurs
#     in that shell's own command line. It kills the wrong process and the silence
#     looks like a hang. Hence a pid file, and killing that pid and nothing else.
#   - Two overlapping ramps would each run `brightnessctl -s`, so the second save
#     would capture an already-dimmed panel and `wake` would restore to the dim
#     value instead of the user's own brightness. Hence the "already fading" guard.
#   - hypridle runs these through `/bin/sh -c` and does not care whether a command
#     succeeded, so nothing here may rely on a non-zero exit to stop the next step.
#   - A bash `trap` on TERM runs the handler and then *continues*, so a trap that
#     only cleans up would let the ramp keep dimming after `wake` restored the
#     brightness. The handler exits.
set -u

RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUNDIR/hypr-dim-ramp.pid"
HZ=20       # brightness writes per second: smooth, and one cheap exec per step
MIN_RAW=1   # 0 is "panel off" on amdgpu, which is dpms by another name

# Prints the pid of a fade in progress, or fails if there is none.
fading_pid() {
    local pid
    [ -f "$PIDFILE" ] || return 1
    pid="$(cat "$PIDFILE" 2>/dev/null)" || return 1
    case "$pid" in '' | *[!0-9]*) return 1 ;; esac
    kill -0 "$pid" 2>/dev/null || return 1
    printf '%s' "$pid"
}

stop_ramp() {
    local pid
    if pid="$(fading_pid 2>/dev/null)"; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
}

# brightnessctl keeps the saved level in a temp file for the whole session, so a
# restore with nothing saved is a silent no-op rather than an error. That makes it
# safe to call from after_sleep_cmd on a machine with no backlight at all.
restore() {
    command -v brightnessctl >/dev/null 2>&1 || return 0
    brightnessctl -q -r >/dev/null 2>&1 || true
}

ramp() {
    local secs="$1" pct="$2"

    command -v brightnessctl >/dev/null 2>&1 || return 0

    # A desktop with only external monitors has no backlight device. That is a
    # normal machine, not a failure: brightnessctl errors and the ladder carries on.
    local from max to
    from="$(brightnessctl -q get 2>/dev/null)" || return 0
    max="$(brightnessctl -q max 2>/dev/null)" || return 0
    case "$from$max" in '' | *[!0-9]*) return 0 ;; esac
    [ "$max" -gt 0 ] || return 0

    to=$(( max * pct / 100 ))
    [ "$to" -lt "$MIN_RAW" ] && to="$MIN_RAW"
    [ "$to" -gt "$max" ] && to="$max"

    # Already darker than the target: a "fade down" would brighten the panel.
    [ "$from" -le "$to" ] && return 0

    # A fade already in flight owns the saved level; starting a second one would
    # save the half-dimmed value as if it were the user's own.
    fading_pid >/dev/null 2>&1 && return 0

    brightnessctl -q -s >/dev/null 2>&1 || true
    printf '%s' "$$" > "$PIDFILE"
    trap 'rm -f "$PIDFILE"' EXIT
    trap 'rm -f "$PIDFILE"; exit 0' INT TERM

    local steps=$(( secs * HZ )) i p s value
    for (( i = 1; i <= steps; i++ )); do
        p=$(( i * 1000 / steps ))
        # smoothstep. p is per-mille progress, s comes out as 0..1000000. A linear
        # fade spends most of its time in the invisible tail and reads as a stall.
        s=$(( p * p * (3000 - 2 * p) / 1000 ))
        value=$(( from + (to - from) * s / 1000000 ))
        [ "$value" -lt "$MIN_RAW" ] && value="$MIN_RAW"
        [ "$value" -gt "$max" ] && value="$max"
        brightnessctl -q set "$value" >/dev/null 2>&1 || break
        sleep 0.05
    done
}

cmd="${1:-dim}"
shift 2>/dev/null || true

case "$cmd" in
    dim)    ramp "${1:-45}" "${2:-10}" ;;
    wake)   stop_ramp; restore ;;
    cancel) stop_ramp ;;
    *)
        printf 'usage: %s dim [seconds] [percent] | wake | cancel\n' "$0" >&2
        exit 2
        ;;
esac
