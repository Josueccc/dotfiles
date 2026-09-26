#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

symlink() {
    local src="$1" dst="$2"

    if [ ! -e "$src" ]; then
        yellow "  skip (missing): $src"
        return
    fi

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        green "  ok: $dst"
        return
    fi

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        yellow "  backup: $dst → $dst.bak"
        mv "$dst" "$dst.bak"
    fi

    ln -sf "$src" "$dst"
    green "  linked: $dst → $src"
}

source_line() {
    local file="$1" line="$2"
    if [ ! -f "$file" ]; then return; fi
    if grep -qF "$line" "$file"; then
        green "  ok (already sourced): $file"
    else
        echo "$line" >> "$file"
        green "  patched: $file"
    fi
}

detect_distro() {
    [ -f /etc/os-release ] || { echo "unknown"; return; }
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
        arch|manjaro|endeavouros|garuda|cachyos) echo "arch"   ;;
        fedora|nobara)                           echo "fedora" ;;
        debian|ubuntu|linuxmint|pop|raspbian)    echo "debian" ;;
        *)
            case "${ID_LIKE:-}" in
                *arch*)            echo "arch"   ;;
                *fedora*|*rhel*)   echo "fedora" ;;
                *debian*|*ubuntu*) echo "debian" ;;
                *)                 echo "unknown" ;;
            esac ;;
    esac
}

usage() {
    cat <<EOF
Usage: $0 [--mode MODE] [--distro DISTRO]

  --mode    cli      Symlink CLI and TUI configs only
            desktop  Symlink CLI + full desktop configs
  --distro  arch     Arch Linux and derivatives
            fedora   Fedora and derivatives
            debian   Debian/Ubuntu — cli mode only
  -h|--help Show this help

If --mode is omitted and stdin is a TTY, you will be prompted.
If --distro is omitted, it is auto-detected from /etc/os-release.
EOF
}

# ── Arg parsing ────────────────────────────────────────────────────────────────
MODE=""
DISTRO=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)    MODE="$2";   shift 2 ;;
        --distro)  DISTRO="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) red "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── Distro ─────────────────────────────────────────────────────────────────────
if [ -z "$DISTRO" ]; then
    DISTRO="$(detect_distro)"
    if [ "$DISTRO" = "unknown" ]; then
        yellow "Could not detect distro. Defaulting to arch. Use --distro to override."
        DISTRO="arch"
    else
        yellow "Detected distro: $DISTRO"
    fi
fi

case "$DISTRO" in
    arch|fedora|debian) ;;
    *) red "Unsupported distro: $DISTRO (use arch, fedora, or debian)"; exit 1 ;;
esac

# ── Mode ───────────────────────────────────────────────────────────────────────
if [ -z "$MODE" ]; then
    if [ "$DISTRO" = "debian" ]; then
        MODE="cli"
        yellow "Debian detected — using cli mode (desktop not supported)."
    elif [ -t 0 ]; then
        echo ""
        echo "Select install mode:"
        echo "  1) cli     — CLI tools and TUIs only"
        echo "  2) desktop — Full setup including Hyprland desktop"
        read -rp "Choice [1/2, default 1]: " _choice
        case "${_choice:-1}" in
            2) MODE="desktop" ;;
            *) MODE="cli" ;;
        esac
    else
        MODE="cli"
    fi
fi

case "$MODE" in
    cli|desktop) ;;
    *) red "Unknown mode: $MODE (use cli or desktop)"; exit 1 ;;
esac

if [ "$MODE" = "desktop" ] && [ "$DISTRO" = "debian" ]; then
    yellow "Desktop mode not supported on Debian. Switching to cli."
    MODE="cli"
fi

# ── Symlinks ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Symlinking configs  [mode=$MODE  distro=$DISTRO]"

# CLI configs — always applied
symlink "$DOTFILES/nvim"                   "$HOME/.config/nvim"
symlink "$DOTFILES/.tmux.conf"             "$HOME/.tmux.conf"
symlink "$DOTFILES/fish"                   "$HOME/.config/fish"
symlink "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"
symlink "$DOTFILES/lazygit"                "$HOME/.config/lazygit"
symlink "$DOTFILES/btop"                   "$HOME/.config/btop"
symlink "$DOTFILES/alacritty"              "$HOME/.config/alacritty"
symlink "$DOTFILES/kitty"                  "$HOME/.config/kitty"

# OpenCode. Linked file by file, NOT the whole ~/.config/opencode directory:
# opencode also keeps machine-generated state there (service.json holds the
# service password), and that must never end up in the repo.
symlink "$DOTFILES/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
symlink "$DOTFILES/opencode/cli.json"      "$HOME/.config/opencode/cli.json"

# Desktop configs — only when mode=desktop
if [ "$MODE" = "desktop" ]; then
    echo ""
    echo "==> Symlinking desktop configs"

    symlink "$DOTFILES/hyprland/hyprland.lua"       "$HOME/.config/hypr/hyprland.lua"
    symlink "$DOTFILES/hyprland/hyprlock.conf"      "$HOME/.config/hypr/hyprlock.conf"
    symlink "$DOTFILES/hyprland/hypridle.conf"      "$HOME/.config/hypr/hypridle.conf"
    symlink "$DOTFILES/hyprland/hyprsunset.conf"    "$HOME/.config/hypr/hyprsunset.conf"
    symlink "$DOTFILES/hyprland/scripts/nightlight.sh" "$HOME/.config/hypr/scripts/nightlight.sh"
    symlink "$DOTFILES/hyprland/scripts/dim-ramp.sh"   "$HOME/.config/hypr/scripts/dim-ramp.sh"
    symlink "$DOTFILES/hyprland/scripts/toggle-kb-layout.sh" "$HOME/.config/hypr/scripts/toggle-kb-layout.sh"
    symlink "$DOTFILES/hyprland/hyprqt6engine.conf" "$HOME/.config/hypr/hyprqt6engine.conf"
    symlink "$DOTFILES/rofi"                        "$HOME/.config/rofi"
    symlink "$DOTFILES/swaync"                      "$HOME/.config/swaync"
    symlink "$DOTFILES/waybar"                      "$HOME/.config/waybar"
    symlink "$DOTFILES/waypaper"                    "$HOME/.config/waypaper"
    symlink "$DOTFILES/wallust"                     "$HOME/.config/wallust"
    # The dashboard overlay (roadmap 3.1). The whole directory, not just
    # shell.qml, because quickshell requires its config to live at
    # ~/.config/quickshell/shell.qml to be registered as the 'default'
    # config — a bare shell.qml symlink is enough for that, but generated-
    # colors.json has to sit next to it for Quickshell.shellPath() to find it,
    # and the README belongs with the code.
    symlink "$DOTFILES/quickshell"                  "$HOME/.config/quickshell"
    symlink "$DOTFILES/cava/config"                 "$HOME/.config/cava/config"
    symlink "$DOTFILES/qt5ct"                       "$HOME/.config/qt5ct"
    symlink "$DOTFILES/qt6ct"                       "$HOME/.config/qt6ct"
    symlink "$DOTFILES/kvantum"                     "$HOME/.config/Kvantum"
    symlink "$DOTFILES/kde/kdeglobals"              "$HOME/.config/kdeglobals"
    # Makes GTK3 read the matugen-generated palette. Only the entry point is
    # symlinked — colors.css next to it is generated and machine-specific.
    symlink "$DOTFILES/gtk/gtk-3.0/gtk.css"         "$HOME/.config/gtk-3.0/gtk.css"

    # Firefox cannot be symlinked the usual way: its profile directory is named
    # with a random hash and the whole ~/.config/mozilla tree is Firefox's, so
    # the theme files are linked INTO the profile one at a time. The script
    # resolves profiles.ini itself and no-ops with a clear message if Firefox
    # has never been run.
    if [ -x "$DOTFILES/firefox/link-profile.sh" ]; then
        bash "$DOTFILES/firefox/link-profile.sh" || true
    fi
fi

# ── Shell rc sourcing ──────────────────────────────────────────────────────────
echo ""
echo "==> Sourcing custom.sh in shell configs"

CUSTOM_LINE="[ -f \"$DOTFILES/custom.sh\" ] && source \"$DOTFILES/custom.sh\""
source_line "$HOME/.bashrc" "$CUSTOM_LINE"
source_line "$HOME/.zshrc"  "$CUSTOM_LINE"

# ── Generated theme colors ─────────────────────────────────────────────────────
if [ "$MODE" = "desktop" ]; then
    echo ""
    echo "==> Seeding fallback theme colors (wallust overwrites these later)"
    bash "$DOTFILES/wallust/apply-theme.sh" --seed

    # waypaper rewrites config.ini on every wallpaper change, so the live file is
    # gitignored and seeded from a template instead. The template only fills in
    # what is missing, so a wallpaper you already picked survives a re-run.
    echo ""
    echo "==> Seeding waypaper config from template"
    if [ -f "$DOTFILES/waypaper/config.ini.template" ]; then
        if [ ! -f "$HOME/.config/waypaper/config.ini" ]; then
            cp "$DOTFILES/waypaper/config.ini.template" "$HOME/.config/waypaper/config.ini"
            green "  seeded: $HOME/.config/waypaper/config.ini"
        else
            # Keep the machine's volatile keys, take everything else from the
            # template: wallpaper, backend, folder, monitors and style paths.
            python3 - "$DOTFILES/waypaper/config.ini.template" "$HOME/.config/waypaper/config.ini" <<'PY'
import configparser, sys

template_path, live_path = sys.argv[1], sys.argv[2]
keep = ("wallpaper", "backend", "folder", "monitors", "stylesheet", "keybindings",
        "wallpaperengine_folder", "wallpaperengine_socket", "use_xdg_state")

live = configparser.ConfigParser()
live.read(live_path)

tpl = configparser.ConfigParser()
tpl.read(template_path)

if not live.has_section("Settings"):
    live.add_section("Settings")

changed = []
for key, value in tpl["Settings"].items():
    if key in keep and live.has_option("Settings", key):
        continue
    if not live.has_option("Settings", key) or live["Settings"][key] != value:
        live.set("Settings", key, value)
        changed.append(key)

if changed:
    with open(live_path, "w") as fh:
        live.write(fh)
    print(f"  updated: {live_path} ({', '.join(changed)})")
else:
    print(f"  ok: {live_path} (already up to date)")
PY
        fi
    else
        yellow "  skip (missing): $DOTFILES/waypaper/config.ini.template"
    fi
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "==> Done."
echo ""
echo "Notes:"
echo "  - tmux plugins : inside tmux run  prefix + I  (via tpm)"
echo "  - nvim plugins : open nvim and run  :PlugInstall"
echo "  - packages     : run  ./packages.sh --mode $MODE --distro $DISTRO"
echo ""
