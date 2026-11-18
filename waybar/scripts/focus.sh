#!/usr/bin/env bash
# focus.sh — Flowtime focus timer for the bar (with a classic Pomodoro mode).
#
# Flowtime: start a focus block, stop it when YOU decide, and the break is a
# fraction of what you worked (focus / BREAK_RATIO). Nothing interrupts you
# mid-flow except one optional nudge at NUDGE_MIN. Pomodoro mode is the fixed
# FOCUS 25 / BREAK 5 cycle for days when structure helps more than flow.
#
#   focus.sh toggle   idle → focus → break → (skip break) focus
#   focus.sh stop     back to idle from anywhere (a running focus is logged)
#   focus.sh mode     flow ↔ pomodoro (only while idle)
#   focus.sh watch    JSON stream for waybar's custom/focus (one line per second)
#   focus.sh status   one human-readable line, for the terminal
#
# Timers are transient systemd --user units (rizz-focus-*.timer), not sleeping
# shells: they survive a waybar restart and are cancelled by name. State lives in
# $XDG_STATE_HOME/rizz-focus/: `state` (mode phase start end), `log.tsv` (one row
# per finished focus block) and `today` (the cached day total the bar reads, so
# the per-second loop never re-scans the log).

set -u

BREAK_RATIO=5          # flow: break = focus / 5   (50 min → 10 min)
MIN_BREAK=60           # seconds; a 2-minute focus still earns a real pause
MIN_FOCUS=60           # a focus shorter than this is a false start: no break, not logged
NUDGE_MIN=90           # flow: one gentle notification after this long (0 = off)
POMO_FOCUS=25          # minutes
POMO_BREAK=5           # minutes
DND_DURING_FOCUS=1     # swaync do-not-disturb while focusing, restored afterwards

DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rizz-focus"
STATE="$DIR/state"
LOG="$DIR/log.tsv"
TODAY="$DIR/today"
LOCK="$DIR/lock"
SELF="$(readlink -f "$0")"

# Glyphs by codepoint (see CLAUDE.md: typed PUA glyphs land on the wrong one).
# Each was rendered from the TTF before being chosen.
G_IDLE=$'\U000F051B'   # timer outline
G_FLOW=$'\U000F04FE'   # crosshairs — focus, flow mode
G_POMO=$'\U000F051F'   # hourglass — focus, pomodoro mode
G_BREAK=$'\U000F0176'  # coffee

mkdir -p "$DIR"

now() { printf '%(%s)T' -1; }

# state: "<mode> <phase> <start> <end>"   mode=flow|pomo  phase=idle|focus|break
read_state() {
    mode=flow phase=idle start=0 end=0
    [[ -r $STATE ]] && read -r mode phase start end < "$STATE"
    : "${mode:=flow}" "${phase:=idle}" "${start:=0}" "${end:=0}"
}
write_state() { printf '%s %s %s %s\n' "$mode" "$phase" "$start" "$end" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }

fmt() {  # seconds → M:SS or H:MM:SS
    local s=$1
    if (( s >= 3600 )); then printf '%d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60))
    else printf '%02d:%02d' $((s/60)) $((s%60)); fi
}
human() {  # seconds → "1h 05m" / "12m"
    local s=$1
    if (( s >= 3600 )); then printf '%dh %02dm' $((s/3600)) $((s%3600/60)); else printf '%dm' $((s/60)); fi
}

notify() { notify-send -a "Focus" -i "${3:-alarm-symbolic}" "$1" "$2"; }
# Synchronous on purpose: from a systemd timer, a backgrounded paplay is killed
# with the unit's cgroup the moment the script exits.
chime()  { paplay "/usr/share/sounds/freedesktop/stereo/${1:-complete}.oga" 2>/dev/null; }

timer_start() {  # name seconds subcommand
    systemctl --user stop "rizz-focus-$1.timer" 2>/dev/null
    systemd-run --user --quiet --collect --unit="rizz-focus-$1" ${XDG_STATE_HOME:+--setenv=XDG_STATE_HOME="$XDG_STATE_HOME"} \
        --on-active="$2s" --timer-property=AccuracySec=1s "$SELF" "$3" >/dev/null
}
# One unit per call: a multi-unit `stop` aborts on the first one that is not
# loaded, which left the 90-min nudge armed after every focus without it.
# Never stops $SELF_TIMER, the timer whose service is running this very
# script: stopping it from inside sends that service SIGTERM mid-transition.
SELF_TIMER=""
timers_stop() {
    local u
    for u in nudge focusend breakend; do
        [[ $u == "$SELF_TIMER" ]] || systemctl --user stop "rizz-focus-$u.timer" 2>/dev/null
    done
}

dnd_on() {
    (( DND_DURING_FOCUS )) && command -v swaync-client >/dev/null || return 0
    # Remember whether DND was already on, so we never switch off the user's own.
    [[ $(swaync-client -D 2>/dev/null) == true ]] && echo user > "$DIR/dnd" || { echo focus > "$DIR/dnd"; swaync-client -dn >/dev/null; }
}
dnd_off() {
    [[ -r $DIR/dnd ]] || return 0
    [[ $(< "$DIR/dnd") == focus ]] && swaync-client -df >/dev/null 2>&1
    rm -f "$DIR/dnd"
}

update_today() {  # recompute the cached total for today from the log
    local d sd n=0 total=0 s e secs
    d=$(printf '%(%F)T' -1)
    if [[ -r $LOG ]]; then
        while IFS=$'\t' read -r s e secs _; do
            printf -v sd '%(%F)T' "$s"
            [[ $sd == "$d" ]] && (( n++, total += secs ))
        done < "$LOG"
    fi
    printf '%s %s %s\n' "$d" "$total" "$n" > "$TODAY"
}

start_focus() {
    phase=focus start=$(now) end=0
    timers_stop
    if [[ $mode == pomo ]]; then
        end=$(( start + POMO_FOCUS * 60 ))
        timer_start focusend $(( POMO_FOCUS * 60 )) _focus_done
    elif (( NUDGE_MIN > 0 )); then
        timer_start nudge $(( NUDGE_MIN * 60 )) _nudge
    fi
    write_state
    dnd_on
}

log_focus() {  # end worked break
    printf '%s\t%s\t%s\t%s\t%s\n' "$start" "$1" "$2" "$3" "$mode" >> "$LOG"
    update_today
}

# Close the running focus block: log it and start the break it earned.
end_focus() {
    local t worked brk
    t=$(now); worked=$(( t - start ))
    timers_stop
    dnd_off
    if (( worked < MIN_FOCUS )) || [[ ${1:-} == nobreak ]]; then
        (( worked >= MIN_FOCUS )) && log_focus "$t" "$worked" 0
        phase=idle start=0 end=0; write_state; return
    fi
    if [[ $mode == pomo ]]; then brk=$(( POMO_BREAK * 60 ))
    else brk=$(( worked / BREAK_RATIO )); (( brk < MIN_BREAK )) && brk=$MIN_BREAK; fi
    log_focus "$t" "$worked" "$brk"
    phase=break start=$t end=$(( t + brk ))
    # A different unit name from the focus timer: this runs INSIDE
    # rizz-focus-focusend.service in pomodoro mode, and systemd-run refuses a
    # name that is still active.
    timer_start breakend "$brk" _break_done
    write_state
    notify "Descanso: $(human "$brk")" "Trabajaste $(human "$worked"). Levántate, mira lejos, toma agua." coffee
}

# All mutations go through the lock: a click and a timer firing together must
# not both read the same state and both write their own answer.
exec 9> "$LOCK"
case "${1:-status}" in
    toggle)
        flock 9; read_state
        case $phase in
            idle)  start_focus ;;
            focus) end_focus ;;
            break) timers_stop; start_focus ;;   # skip the rest of the break
        esac ;;
    stop)
        flock 9; read_state
        [[ $phase == focus ]] && end_focus nobreak   # the work still counts
        timers_stop; dnd_off
        phase=idle start=0 end=0; write_state ;;
    mode)
        flock 9; read_state
        if [[ $phase == idle ]]; then
            [[ $mode == flow ]] && mode=pomo || mode=flow
            write_state
            notify "Modo: $([[ $mode == flow ]] && echo "Flowtime" || echo "Pomodoro ${POMO_FOCUS}/${POMO_BREAK}")" "" timer
        else
            notify "Termina la sesión primero" "El modo se cambia sin una sesión en curso." dialog-information
        fi ;;
    _focus_done)   # pomodoro focus timer expired
        SELF_TIMER=focusend; flock 9; read_state
        [[ $phase == focus ]] && { chime complete; end_focus; } ;;
    _break_done)
        SELF_TIMER=breakend; flock 9; read_state
        if [[ $phase == break ]]; then
            phase=idle start=0 end=0; write_state
            chime bell
            notify "Descanso terminado" "Super+O para otra sesión." alarm-symbolic
        fi ;;
    _nudge)
        read_state
        [[ $phase == focus ]] && notify "Llevas $(human $(( $(now) - start )))" "Si sigues en flow, ignora esto. Si no, Super+O y descansa." dialog-information ;;
    watch)
        exec 9>&-
        update_today
        prev=""
        while :; do
            read_state
            t=$(now)
            tday=0 tn=0 tdate=""
            [[ -r $TODAY ]] && read -r tdate tday tn < "$TODAY"
            printf -v d '%(%F)T' -1
            [[ $tdate == "$d" ]] || tday=0 tn=0
            modename=$([[ $mode == flow ]] && echo "Flowtime" || echo "Pomodoro ${POMO_FOCUS}/${POMO_BREAK}")
            stats="Hoy: $(human "$tday") en $tn $( ((tn == 1)) && echo sesión || echo sesiones)"
            case $phase in
                focus)
                    if [[ $mode == pomo ]]; then
                        left=$(( end - t )); (( left < 0 )) && left=0
                        text="$G_POMO $(fmt "$left")"; cls=focus
                    else
                        el=$(( t - start ))
                        text="$G_FLOW $(fmt "$el")"; cls=focus
                        (( NUDGE_MIN > 0 && el >= NUDGE_MIN * 60 )) && cls="focus long"
                    fi
                    tip="En foco desde $(printf '%(%H:%M)T' "$start") · $modename\n$stats\n\nclic: terminar y descansar · der: cancelar" ;;
                break)
                    left=$(( end - t )); (( left < 0 )) && left=0
                    text="$G_BREAK $(fmt "$left")"; cls=break
                    tip="Descanso hasta $(printf '%(%H:%M)T' "$end")\n$stats\n\nclic: saltar descanso · der: parar" ;;
                *)
                    text="$G_IDLE"; cls=idle
                    tip="Foco · $modename\n$stats\n\nclic / Super+O: empezar\nmedio: cambiar modo" ;;
            esac
            out=$(printf '{"text":"%s","class":"%s","tooltip":"%s","alt":"%s"}' "$text" "$cls" "$tip" "$phase")
            [[ $out != "$prev" ]] && { printf '%s\n' "$out"; prev=$out; }
            sleep 1
        done ;;
    status)
        read_state
        t=$(now)
        case $phase in
            focus) echo "focus ($mode) $(fmt $(( t - start )))" ;;
            break) echo "break $(fmt $(( end - t ))) left" ;;
            *)     echo "idle ($mode)" ;;
        esac ;;
    *) echo "usage: $0 toggle|stop|mode|watch|status" >&2; exit 2 ;;
esac
