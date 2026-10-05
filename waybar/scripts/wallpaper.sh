#!/usr/bin/env bash
# wallpaper.sh — the one way to change the wallpaper (roadmap 4.1 / 5.1).
#
#   wallpaper.sh set <file>   Image or video. Re-themes the desktop either way.
#   wallpaper.sh restore      Login: put back whatever was set last.
#   wallpaper.sh list         TSV for the quickshell picker: kind, path, thumb.
#   wallpaper.sh current      Print the path last set.
#
# Images still go through waypaper, exactly as before — it owns awww, the wave
# transition and post_command → wallust/apply-theme.sh. Videos are layered ON
# TOP of that rather than replacing it:
#
#   1. ffmpeg grabs the video's first frame to a PNG.
#   2. waypaper sets THAT frame through awww. So the transition still plays, and
#      post_command themes the desktop from the frame — wallust cannot read a
#      video, and neither can SDDM, which gets the frame copied as its picture.
#   3. mpvpaper starts on the same outputs. A layer created later stacks above
#      an earlier one on the same level (verified with `hyprctl layers`:
#      mpvpaper lists after awww-daemon on both monitors), so the video covers
#      the still and the handoff is invisible, because the still IS frame 0.
#
# The still underneath is worth keeping: if mpvpaper dies, the desktop shows
# the same frame instead of whatever was behind it.
#
# Why not waypaper's own mpvpaper backend: its awww backend never kills
# mpvpaper and its mpvpaper backend never kills awww, so switching between them
# leaves both painting; it hands the video path to post_command, which wallust
# cannot read; and it has no way to pass mpvpaper's -p (pause while hidden).
set -u

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
WALLPAPER_DIR="${WALLPAPER_DIR%/}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rizz-wallpaper"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rizz-wallpaper"
THUMBS="$CACHE/thumbs"
FRAMES="$CACHE/frames"
mkdir -p "$STATE" "$THUMBS" "$FRAMES"

# 640px wide: the picker's side cards are ~300 logical px (375 physical at 1.25)
# and the centre card loads the original itself, so this is only the strip.
THUMB_W=640

# hwdec=auto-safe → vaapi on the Vega iGPU (checked: `hwdec-current` = vaapi),
# ~12% of one core for 1080p30 across both outputs. no-audio, not mute: there is
# no reason to open an audio stream at all. panscan=1.0 is "fill", matching
# waypaper's fill = fill for images.
MPV_OPTS="no-audio loop hwdec=auto-safe panscan=1.0"

is_video() {
    case "${1,,}" in
        *.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v) return 0 ;;
    esac
    return 1
}

# Cache names are the path relative to the wallpaper dir with / → __, so two
# files with the same basename in different subfolders cannot collide. NOT %:
# the frame path ends up in waypaper's state.ini, which configparser writes
# with interpolation on — a % there makes waypaper fail to save its state
# ("invalid interpolation syntax") and --restore then brings back the old one.
cache_name() { local r="${1#"$WALLPAPER_DIR"/}"; printf '%s' "${r//\//__}"; }

# Exact-name match: the comm of every mpvpaper is "mpvpaper", and nothing that
# calls this script is. `pkill -f` would be the trap from CLAUDE.md — the
# pattern sits in the caller's own command line.
stop_video() { pkill -x mpvpaper >/dev/null 2>&1 && sleep 0.1; return 0; }

start_video() { # start_video <file>
    # -p pauses mpv while the wallpaper is fully hidden; -a full extends that to
    # "any window is fullscreen", so a fullscreen game or video costs nothing.
    mpvpaper -f -p -a full -o "$MPV_OPTS" '*' "$1" >/dev/null 2>&1
}

frame_of() { # frame_of <video> → prints the PNG path
    local out="$FRAMES/$(cache_name "$1").png"
    if [ ! -s "$out" ] || [ "$1" -nt "$out" ]; then
        ffmpeg -loglevel error -y -i "$1" -frames:v 1 "$out" </dev/null || return 1
    fi
    printf '%s' "$out"
}

set_still() { # set_still <image>  — through waypaper when it exists
    if command -v waypaper >/dev/null 2>&1; then
        waypaper --backend awww --wallpaper "$1"
        return
    fi
    # Machines without waypaper: drive awww directly and re-theme by hand,
    # because nothing else will fire apply-theme.sh.
    if command -v awww >/dev/null 2>&1; then
        awww query >/dev/null 2>&1 || {
            pkill -x swaybg >/dev/null 2>&1
            setsid awww-daemon >/dev/null 2>&1 &
            sleep 0.4
        }
        awww img "$1" --transition-type wave --transition-angle 30 \
            --transition-fps 60 --transition-duration 1.2 --transition-step 20
    elif command -v swaybg >/dev/null 2>&1; then
        pkill -x swaybg >/dev/null 2>&1
        setsid swaybg -i "$1" -m fill >/dev/null 2>&1 &
    fi
    "$HOME/.config/wallust/apply-theme.sh" "$1"
}

cmd_set() { # cmd_set <file>
    local file="$1" frame
    [ -f "$file" ] || { echo "no such file: $file" >&2; return 1; }
    # Stop the video FIRST in both branches: awww still holds the last still
    # underneath, so the screen never goes empty, and the wave transition then
    # plays from it.
    stop_video
    if is_video "$file"; then
        command -v mpvpaper >/dev/null 2>&1 || { echo "mpvpaper not installed" >&2; return 1; }
        frame=$(frame_of "$file") || { echo "could not extract a frame" >&2; return 1; }
        set_still "$frame"
        # Let the 1.2s transition land on the frame before the video covers
        # it, or the swoosh is cut off half way.
        sleep 1.3
        start_video "$file"
    else
        set_still "$file"
    fi
    printf '%s\n' "$file" > "$STATE/current"
}

cmd_restore() {
    # waypaper restores the still (an image, or a video's frame) and fires
    # post_command, as it always did at login. The video, if any, goes on top.
    command -v waypaper >/dev/null 2>&1 && waypaper --restore
    local cur
    cur=$(cat "$STATE/current" 2>/dev/null) || return 0
    if is_video "$cur" && [ -f "$cur" ] && command -v mpvpaper >/dev/null 2>&1; then
        stop_video
        start_video "$cur"
    fi
}

thumb_one() { # thumb_one <file>  (run in parallel by cmd_list)
    local src="$1" out="$THUMBS/$(cache_name "$1").jpg"
    [ -s "$out" ] && [ ! "$src" -nt "$out" ] && return 0
    if is_video "$src"; then
        ffmpegthumbnailer -s "$THUMB_W" -q 8 -t 0 -i "$src" -o "$out" >/dev/null 2>&1
    else
        # [0] = first frame, so a GIF thumbnails instead of erroring out.
        vipsthumbnail "$src[0]" -s "${THUMB_W}x" -o "$out[Q=85,strip]" >/dev/null 2>&1 ||
            magick "$src[0]" -thumbnail "${THUMB_W}x" "$out" >/dev/null 2>&1
    fi
}

cmd_list() {
    local files
    # -L: a symlinked wallpaper (or folder of them) is listed like a file.
    files=$(find -L "$WALLPAPER_DIR" -maxdepth 3 -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
            -iname '*.webp' -o -iname '*.gif' -o \
            -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o \
            -iname '*.mov' -o -iname '*.m4v' \) | sort -f)
    # Missing thumbnails are made before anything is printed, all cores at
    # once. First run over ~400 files took 19s; afterwards nothing is spawned
    # at all — the staleness test happens here, so xargs only ever sees the
    # files that need work (one bash per file was 0.5s even when all fresh).
    local f r kind out rows="" missing=()
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        is_video "$f" && kind=video || kind=image
        # cache_name inlined: a $(...) per file is a fork per file.
        r="${f#"$WALLPAPER_DIR"/}"; out="$THUMBS/${r//\//__}.jpg"
        { [ -s "$out" ] && [ ! "$f" -nt "$out" ]; } || missing+=("$f")
        rows+="$kind"$'\t'"$f"$'\t'"$out"$'\n'
    done <<< "$files"
    if [ "${#missing[@]}" -gt 0 ]; then
        export -f thumb_one is_video cache_name
        export WALLPAPER_DIR THUMBS THUMB_W
        printf '%s\0' "${missing[@]}" |
            xargs -0 -r -P "$(nproc)" -I{} bash -c 'thumb_one "$1"' _ {}
    fi
    printf '%s' "$rows"
}

case "${1:-}" in
    set)     shift; cmd_set "${1:?usage: wallpaper.sh set <file>}" ;;
    restore) cmd_restore ;;
    list)    cmd_list ;;
    current) cat "$STATE/current" 2>/dev/null ;;
    *)       sed -n '2,7p' "$0" >&2; exit 2 ;;
esac
