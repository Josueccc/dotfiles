#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red() { printf '\033[0;31m%s\033[0m\n' "$*"; }

symlink() {
    local src="$1"
    local dst="$2"

    if [ ! -e "$src" ]; then
        yellow "  skip (source missing): $src"
        return
    fi

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        green "  ok (already linked): $dst"
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
    local file="$1"
    local line="$2"

    if [ ! -f "$file" ]; then return; fi
    if grep -qF "$line" "$file"; then
        green "  ok (already sourced): $file"
    else
        echo "$line" >> "$file"
        green "  patched: $file"
    fi
}

echo ""
echo "==> Symlinking configs"

# ── Neovim ────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/nvim"             "$HOME/.config/nvim"

# ── tmux ──────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/.tmux.conf"       "$HOME/.tmux.conf"

# ── Hyprland ──────────────────────────────────────────────────────────────────
symlink "$DOTFILES/hyprland/hyprland.lua"    "$HOME/.config/hypr/hyprland.lua"

# ── Rofi ──────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/rofi"             "$HOME/.config/rofi"

# ── Kitty ─────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/kitty"            "$HOME/.config/kitty"

# ── Alacritty ─────────────────────────────────────────────────────────────────
symlink "$DOTFILES/alacritty"        "$HOME/.config/alacritty"

# ── Swaync ────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/swaync"           "$HOME/.config/swaync"

# ── Waybar ────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/waybar"           "$HOME/.config/waybar"

# ── Waypaper ──────────────────────────────────────────────────────────────────
symlink "$DOTFILES/waypaper"         "$HOME/.config/waypaper"

# ── Fish ──────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/fish"             "$HOME/.config/fish"

# ── Starship ──────────────────────────────────────────────────────────────────
symlink "$DOTFILES/starship/starship.toml"   "$HOME/.config/starship.toml"

# ── Lazygit ───────────────────────────────────────────────────────────────────
symlink "$DOTFILES/lazygit"          "$HOME/.config/lazygit"

# ── btop ──────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/btop"             "$HOME/.config/btop"

# ── Hyprlock ──────────────────────────────────────────────────────────────────
symlink "$DOTFILES/hyprland/hyprlock.conf"   "$HOME/.config/hypr/hyprlock.conf"

# ── Hypridle ──────────────────────────────────────────────────────────────────
symlink "$DOTFILES/hyprland/hypridle.conf"        "$HOME/.config/hypr/hypridle.conf"
symlink "$DOTFILES/hyprland/hyprqt6engine.conf"  "$HOME/.config/hypr/hyprqt6engine.conf"

# ── Qt5ct ─────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/qt5ct"            "$HOME/.config/qt5ct"

# ── Qt6ct ─────────────────────────────────────────────────────────────────────
symlink "$DOTFILES/qt6ct"            "$HOME/.config/qt6ct"

# ── Kvantum ───────────────────────────────────────────────────────────────────
symlink "$DOTFILES/kvantum"          "$HOME/.config/Kvantum"

# ── KDE globals (widget style for KDE apps like Dolphin) ──────────────────────
symlink "$DOTFILES/kde/kdeglobals"   "$HOME/.config/kdeglobals"

echo ""
echo "==> Sourcing custom.sh in shell configs"

CUSTOM_SOURCE="[ -f \"$DOTFILES/custom.sh\" ] && source \"$DOTFILES/custom.sh\""
source_line "$HOME/.bashrc"  "$CUSTOM_SOURCE"
source_line "$HOME/.zshrc"   "$CUSTOM_SOURCE"

echo ""
echo "==> Done."
echo ""
echo "Notes:"
echo "  - tmux plugins: run  prefix + I  inside tmux to install via tpm"
echo "  - nvim plugins: open nvim and run  :PlugInstall"
echo "  - fish users: add sourcing of custom.sh manually if needed (fish != bash)"
