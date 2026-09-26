#!/usr/bin/env bash
# apply-theme.sh [wallpaper] — wallpaper-driven theming for the whole desktop.
#
#   apply-theme.sh <image>   Generate palette from <image> and reload all apps.
#   apply-theme.sh           Same, reusing the wallpaper waypaper last set.
#   apply-theme.sh --seed    Write static Catppuccin fallbacks into any missing
#                            generated-colors files (used by install.sh; safe
#                            to re-run — never overwrites real wallust output).
#
# Wired up via waypaper's post_command, so every wallpaper change re-themes:
#   hyprland borders · waybar · rofi · swaync · kitty · alacritty   (wallust)
#   GTK3 apps: thunar, blueman, gnome-disks                        (matugen)
#   Firefox chrome + about: pages                                 (wallust)
#
# Browsers/Electron notes: Firefox is a wallust template like the rest, but it
# cannot follow the ~/.config/<tool>/ convention — its profile dir is named with
# a random hash, so firefox/link-profile.sh resolves profiles.ini and symlinks
# the files into <profile>/chrome/. Brave is NOT in this pipeline: Chromium M154
# deleted the multi-colour theme system, so it accepts a single seed colour and
# must be closed before its Preferences file can be edited. See
# brave/apply-brave-theme.sh.
#
# Two generators on purpose. wallust drives the shell because it is fast and its
# 16-colour palette suits CSS/rasi/kitty. GTK3 is driven by matugen instead
# because gtk-theme-name=Breeze uses ~84 differently-named colour variables
# (theme_base_color_breeze, …) rather than adwaita's accent_color/window_bg_color,
# so it needs a purpose-written template — see matugen/templates/breeze.css.
# Qt6 is NOT handled here: it reads kde/kdeglobals via the "kde" platform theme.
set -u

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallust"
LOG="$CACHE/apply.log"
mkdir -p "$CACHE"

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

# ── Seed mode ─────────────────────────────────────────────────────────────────
# Catppuccin Mocha — matches the static palettes already in the style files.
seed() { # seed <path> <content...>
    local path="$1"; shift
    [ -e "$path" ] && return 0
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
    log "seeded: $path"
}

if [ "${1:-}" = "--seed" ]; then
    seed "$HOME/.config/hypr/generated-colors.lua" \
        '-- Static fallback palette (Catppuccin Mocha). Overwritten by wallust.' \
        'return { color4 = "#89b4fa", color5 = "#cba6f7", color8 = "#595959" }'

    seed "$HOME/.config/waybar/generated-colors.css" \
        '/* Static fallback palette (Catppuccin Mocha). Overwritten by wallust. */' \
        '@define-color base #1e1e2e;  @define-color mantle #181825;  @define-color crust #11111b;' \
        '@define-color surface0 #313244; @define-color surface1 #45475a; @define-color surface2 #585b70;' \
        '@define-color overlay0 #6c7086; @define-color subtext0 #a6adc8; @define-color text #cdd6f4;' \
        '@define-color mauve #cba6f7; @define-color red #f38ba8; @define-color peach #fab387;' \
        '@define-color yellow #f9e2af; @define-color green #a6e3a1; @define-color teal #94e2d5;' \
        '@define-color sapphire #74c7ec; @define-color blue #89b4fa; @define-color lavender #b4befe;'

    seed "$HOME/.config/rofi/generated-colors.rasi" \
        '/* Static fallback palette (Catppuccin Mocha). Overwritten by wallust. */' \
        '* { base: #1e1e2e; mantle: #181825; bg-window: rgba(30,30,46,0.88); bg-input: rgba(24,24,37,0.94);' \
        '    crust: #11111b; surface0: #313244; surface1: #45475a; overlay0: #6c7086;' \
        '    subtext0: #a6adc8; text: #cdd6f4; blue: #89b4fa; mauve: #cba6f7; red: #f38ba8;' \
        '    peach: #fab387; green: #a6e3a1; teal: #94e2d5; }'

    seed "$HOME/.config/swaync/generated-colors.css" \
        '/* Static fallback palette (Catppuccin Mocha). Overwritten by wallust. */' \
        '@define-color base #1e1e2e; @define-color mantle #181825; @define-color surface0 #313244;' \
        '@define-color overlay0 #6c7086; @define-color subtext0 #a6adc8; @define-color text #cdd6f4;' \
        '@define-color blue #89b4fa; @define-color mauve #cba6f7; @define-color red #f38ba8; @define-color green #a6e3a1;'

    seed "$HOME/.config/kitty/generated-colors.conf" \
        '# Static fallback palette (Catppuccin Mocha). Overwritten by wallust.' \
        'foreground #cdd6f4' 'background #1e1e2e' 'cursor #f5e0dc' \
        'cursor_text_color #1e1e2e' 'selection_foreground #1e1e2e' 'selection_background #89b4fa' \
        'url_color #89b4fa' \
        'color0 #45475a'  'color1 #f38ba8' 'color2 #a6e3a1' 'color3 #f9e2af' \
        'color4 #89b4fa'  'color5 #cba6f7' 'color6 #94e2d5' 'color7 #bac2de' \
        'color8 #585b70'  'color9 #f38ba8' 'color10 #a6e3a1' 'color11 #f9e2af' \
        'color12 #89b4fa' 'color13 #cba6f7' 'color14 #94e2d5' 'color15 #a6adc8'

    seed "$HOME/.config/alacritty/generated-colors.toml" \
        '# Static fallback palette (Catppuccin Mocha). Overwritten by wallust.' \
        '[colors.primary]'    'background = "#1e1e2e"' 'foreground = "#cdd6f4"' \
        '[colors.cursor]'     'text = "#1e1e2e"' 'cursor = "#f5e0dc"' \
        '[colors.selection]'  'text = "#1e1e2e"' 'background = "#89b4fa"' \
        '[colors.normal]' \
        'black = "#45475a"' 'red = "#f38ba8"' 'green = "#a6e3a1"' 'yellow = "#f9e2af"' \
        'blue = "#89b4fa"'  'magenta = "#cba6f7"' 'cyan = "#94e2d5"' 'white = "#bac2de"' \
        '[colors.bright]' \
        'black = "#585b70"' 'red = "#f38ba8"' 'green = "#a6e3a1"' 'yellow = "#f9e2af"' \
        'blue = "#89b4fa"'  'magenta = "#cba6f7"' 'cyan = "#94e2d5"' 'white = "#a6adc8"'

    # GTK3 palette. Static Breeze-Dark stand-in so a fresh install has sane dark
    # chrome before matugen has ever run. matugen overwrites this on the first
    # wallpaper change. gtk/gtk-3.0/gtk.css does `@import 'colors.css'`, so this
    # file is the one GTK3 apps actually read.
    seed "$HOME/.config/gtk-3.0/colors.css" \
        '/* Static fallback palette (Catppuccin Mocha as Breeze variables).' \
        '   Overwritten by matugen. GTK3 reads this via @import in gtk.css. */' \
        '@define-color theme_base_color_breeze #1e1e2e;' \
        '@define-color theme_bg_color_breeze   #313244;' \
        '@define-color theme_fg_color_breeze   #cdd6f4;' \
        '@define-color theme_text_color_breeze #cdd6f4;' \
        '@define-color content_view_bg_breeze #1e1e2e;' \
        '@define-color theme_selected_bg_color_breeze #89b4fa;' \
        '@define-color theme_selected_fg_color_breeze #1e1e2e;' \
        '@define-color link_color_breeze #89b4fa;' \
        '@define-color borders_breeze #45475a;' \
        '@define-color error_color_breeze #f38ba8;' \
        '@define-color success_color_breeze #a6e3a1;' \
        '@define-color warning_color_breeze #f9e2af;'

    # Firefox Design System tokens. Note this duplicates the tracked
    # firefox/fallback.css on purpose: the seed must not depend on a file that
    # lives in the repo and could itself be missing, and --seed's whole job is
    # to write something readable without running wallust. userChrome.css
    # imports generated-colors.css LAST, so once wallust runs this is replaced
    # and fallback.css is what you are left with.
    seed "$HOME/.dotfiles/firefox/generated-colors.css" \
        '/* Static fallback palette (Catppuccin Mocha). Overwritten by wallust. */' \
        ':root {' \
        '  --toolbox-background-color: #11111b !important;' \
        '  --toolbox-background-color-inactive: #11111b !important;' \
        '  --toolbox-text-color: #cdd6f4 !important;' \
        '  --toolbox-text-color-inactive: #cdd6f4 !important;' \
        '  --toolbar-background-color: #1e1e2e !important;' \
        '  --toolbar-text-color: #cdd6f4 !important;' \
        '  --toolbar-field-background-color: #11111b !important;' \
        '  --toolbar-field-text-color: #cdd6f4 !important;' \
        '  --toolbar-field-background-color-focus: #11111b !important;' \
        '  --toolbar-field-focus-border-color: #a6adc8 !important;' \
        '  --tab-background-color-selected: #1e1e2e !important;' \
        '  --tab-background-color-hover: #1e1e2e !important;' \
        '  --tab-selected-textcolor: #cdd6f4 !important;' \
        '  --tab-line-selected-color: #89b4fa !important;' \
        '  --tab-line-hover-color: #1e1e2e !important;' \
        '  --urlbar-background-color: #11111b !important;' \
        '  --urlbar-box-background-color: #1e1e2e !important;' \
        '  --urlbar-text-color: #cdd6f4 !important;' \
        '  --sidebar-background-color: #1e1e2e !important;' \
        '  --sidebar-text-color: #cdd6f4 !important;' \
        '  --sidebar-border-color: #1e1e2e !important;' \
        '  --panel-background-color: #1e1e2e !important;' \
        '  --panel-text-color: #cdd6f4 !important;' \
        '  --panel-border-color: #1e1e2e !important;' \
        '  --focus-outline-color: #a6adc8 !important;' \
        '  --color-gray-100: #11111b !important;' \
        '  --color-gray-95: #11111b !important;' \
        '  --color-gray-90: #11111b !important;' \
        '  --color-gray-85: #1e1e2e !important;' \
        '  --color-gray-80: #1e1e2e !important;' \
        '  --color-gray-40: #a6adc8 !important;' \
        '  --color-gray-30: #cdd6f4 !important;' \
        '  --color-gray-20: #cdd6f4 !important;' \
        '  --color-gray-10: #cdd6f4 !important;' \
        '  --color-gray-0: #cdd6f4 !important;' \
        '  --color-accent-primary: #a6adc8 !important;' \
        '  --color-accent-primary-hover: #a6adc8 !important;' \
        '  --color-accent-primary-active: #585b70 !important;' \
        '  --color-accent-primary-selected: #bac2de !important;' \
        '}'
    exit 0
fi

# ── Normal mode ───────────────────────────────────────────────────────────────
command -v wallust >/dev/null 2>&1 || { log "wallust not installed, skipping"; exit 0; }

wallpaper="${1:-}"

# No argument → read the wallpaper waypaper last set
if [ -z "$wallpaper" ]; then
    wallpaper=$(grep -m1 '^wallpaper' "$HOME/.config/waypaper/config.ini" 2>/dev/null | cut -d= -f2- | sed 's/^ *//')
    wallpaper="${wallpaper/#\~/$HOME}"
fi

if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
    log "no usable wallpaper (got '$wallpaper'), skipping"
    exit 0
fi

log "theming from $wallpaper"
wallust run "$wallpaper" >> "$LOG" 2>&1 || { log "wallust failed"; exit 1; }

# GTK3 (thunar, blueman, gnome-disks…) is themed by matugen, not wallust.
# matugen needs --source-color-index 0 here: it runs from waypaper's post_command,
# with no terminal attached, so it cannot prompt when the image has several
# candidate source colours and errors out instead. It is run from the matugen/
# directory because config.toml's input_path is relative to it, and it does
# expand `~` in output_path. A failure here is non-fatal — the seeded fallback
# in colors.css keeps GTK readable.
if command -v matugen >/dev/null 2>&1; then
    if ( cd "$HOME/.dotfiles/matugen" && matugen image "$wallpaper" \
             --config ./config.toml --source-color-index 0 ) >> "$LOG" 2>&1; then
        log "matugen: gtk palette updated"
    else
        log "matugen failed, keeping previous gtk palette (see $LOG)"
    fi
else
    log "matugen not installed, skipping gtk palette"
fi

sleep 0.2  # let wallust finish flushing files

# Reload everything that consumes the generated colors.
# (rofi and hyprlock re-read on launch; alacritty live-reloads imports.)
if pgrep -x waybar >/dev/null; then
    pkill -x waybar
    setsid waybar >/dev/null 2>&1 &
fi
swaync-client -rs >/dev/null 2>&1 &
pkill -USR1 -x kitty 2>/dev/null      # kitty reloads config on SIGUSR1
hyprctl reload >/dev/null 2>&1 &      # border gradient picks up new colors
exit 0
