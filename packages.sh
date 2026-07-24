#!/usr/bin/env bash
# Install packages for a given mode and distro.
# Usage: ./packages.sh [--mode cli|desktop] [--distro arch|fedora|debian] [--dry-run]
set -euo pipefail

# ── Helpers ────────────────────────────────────────────────────────────────────
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
dim()    { printf '\033[0;90m  %s\033[0m\n' "$*"; }
header() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

run() {
    if $DRY_RUN; then
        dim "(dry-run) $*"
    else
        "$@"
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
Usage: $0 [--mode MODE] [--distro DISTRO] [--dry-run]

  --mode    cli      CLI tools and TUIs only
            desktop  Full setup including Hyprland desktop
  --distro  arch     Arch Linux / derivatives  (pacman + AUR)
            fedora   Fedora / derivatives       (dnf + COPR)
            debian   Debian / Ubuntu            (apt, cli mode only)
  --dry-run Print packages that would be installed without installing
  -h|--help Show this help

Distro is auto-detected from /etc/os-release if not specified.
EOF
}

# ── Arg parsing ────────────────────────────────────────────────────────────────
MODE=""
DISTRO=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)    MODE="$2";    shift 2 ;;
        --distro)  DISTRO="$2";  shift 2 ;;
        --dry-run) DRY_RUN=true; shift   ;;
        -h|--help) usage; exit 0 ;;
        *) red "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── Distro ─────────────────────────────────────────────────────────────────────
if [ -z "$DISTRO" ]; then
    DISTRO="$(detect_distro)"
    if [ "$DISTRO" = "unknown" ]; then
        red "Could not detect distro. Use --distro arch|fedora|debian."
        exit 1
    fi
    yellow "Detected distro: $DISTRO"
fi

case "$DISTRO" in
    arch|fedora|debian) ;;
    *) red "Unsupported distro: $DISTRO"; exit 1 ;;
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

if [ "$MODE" = "desktop" ] && [ "$DISTRO" = "debian" ]; then
    yellow "Desktop mode not supported on Debian. Switching to cli."
    MODE="cli"
fi

echo ""
yellow "mode=$MODE  distro=$DISTRO  dry-run=$DRY_RUN"

# ── Package lists ──────────────────────────────────────────────────────────────
# Each distro block defines the arrays it will use; only the relevant block runs.
# MANUAL_NOTES accumulates messages about packages that need manual installation.
MANUAL_NOTES=()

case "$DISTRO" in

# ────────────────────────────────────────────────────────────────────────────
arch)
    PACMAN_CLI=(
        # editor & multiplexer
        neovim tmux
        # search & navigation
        ripgrep fzf fd bat eza zoxide
        # file managers
        yazi ranger
        # system monitoring & prompt
        btop starship
        # shell & terminals
        fish alacritty kitty
        # git
        git lazygit github-cli git-delta
        # misc
        tealdeer curl wget tar zip unzip
    )

    PACMAN_DESKTOP=(
        # Hyprland core
        hyprland hyprlock hypridle hyprsunset hyprpicker
        # launcher & bar
        rofi-wayland waybar
        # wallpaper & clipboard
        swww cliphist wl-clipboard
        # brightness & portals
        brightnessctl
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        # GTK/Qt theming
        nwg-look kvantum qt5ct qt6ct
        # auth & keyring
        polkit-gnome gnome-keyring seahorse openssh
        # audio
        pipewire wireplumber pamixer playerctl pavucontrol
        # network
        networkmanager network-manager-applet nm-connection-editor
        # bluetooth
        bluez bluez-utils blueman
        # file management
        thunar gvfs tumbler ark
    )

    # swaync is in the AUR on Arch; the others below are AUR-only
    AUR_DESKTOP=(
        swaync
        wlogout
        swayosd
        waypaper
        grimblast-git
        catppuccin-gtk-theme-mocha
        bibata-cursor-theme
    )

    PACMAN_FONTS=(
        ttf-jetbrains-mono-nerd
        noto-fonts noto-fonts-emoji
        ttf-font-awesome
        papirus-icon-theme
    )
    ;;

# ────────────────────────────────────────────────────────────────────────────
fedora)
    DNF_CLI=(
        # editor & multiplexer
        neovim tmux
        # search & navigation  (fd is fd-find on Fedora)
        ripgrep fzf fd-find bat eza zoxide
        # file managers
        yazi ranger
        # system monitoring & prompt
        btop starship
        # shell & terminals
        fish alacritty kitty
        # git  (gh is in official Fedora repos since F36)
        git gh git-delta
        # misc
        tealdeer curl wget tar zip unzip
    )
    MANUAL_NOTES+=(
        "lazygit: sudo dnf copr enable atim/lazygit -y && sudo dnf install lazygit -y"
    )

    # solopasha/hyprland COPR covers most of the Hyprland ecosystem on Fedora
    COPR_DESKTOP=(solopasha/hyprland)

    DNF_DESKTOP=(
        # Hyprland core
        hyprland hyprlock hypridle hyprsunset hyprpicker
        # launcher, bar, notifications, wallpaper
        rofi waybar swaync swww waypaper
        # screenshot & OSD
        grimblast cliphist swayosd wlogout
        # brightness & portals
        brightnessctl wl-clipboard
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        # GTK/Qt theming
        nwg-look kvantum qt5ct qt6ct
        # auth & keyring
        polkit-gnome gnome-keyring seahorse openssh
        # audio
        pipewire wireplumber pamixer playerctl pavucontrol
        # network  (Fedora uses uppercase NetworkManager package names)
        NetworkManager NetworkManager-applet nm-connection-editor
        # bluetooth
        bluez bluez-tools blueman
        # file management
        thunar gvfs tumbler ark
    )
    MANUAL_NOTES+=(
        "catppuccin GTK theme: download from github.com/catppuccin/gtk/releases"
        "bibata cursor theme : download from github.com/ful1e5/Bibata_Cursor/releases"
    )

    DNF_FONTS=(
        jetbrains-mono-fonts
        google-noto-fonts-common google-noto-emoji-fonts
        fontawesome-fonts
        papirus-icon-theme
    )
    MANUAL_NOTES+=(
        "JetBrainsMono Nerd Font: download from github.com/ryanoasis/nerd-fonts/releases"
    )
    ;;

# ────────────────────────────────────────────────────────────────────────────
debian)
    APT_CLI=(
        # editor & multiplexer
        neovim tmux
        # search & navigation  (fd-find on Debian/Ubuntu)
        ripgrep fzf fd-find bat eza zoxide
        # file managers
        ranger btop
        # shell & terminals
        fish alacritty kitty
        # git
        git gh
        # misc
        curl wget tar zip unzip
    )
    MANUAL_NOTES+=(
        "starship  : curl -sS https://starship.rs/install.sh | sh"
        "lazygit   : download binary from github.com/jesseduffield/lazygit/releases"
        "git-delta : download binary from github.com/dandavison/delta/releases"
        "tealdeer  : cargo install tealdeer  (or binary from github.com/dbrgn/tealdeer/releases)"
        "yazi      : cargo install yazi-fm   (or binary from github.com/sxyazi/yazi/releases)"
        "JetBrainsMono Nerd Font: github.com/ryanoasis/nerd-fonts/releases"
    )

    APT_FONTS=(
        fonts-noto fonts-noto-color-emoji
        fonts-font-awesome
        papirus-icon-theme
    )
    ;;
esac

# ── AUR helper detection (Arch only) ──────────────────────────────────────────
find_aur_helper() {
    if command -v yay  &>/dev/null; then echo "yay"
    elif command -v paru &>/dev/null; then echo "paru"
    else echo ""
    fi
}

# ── Install functions ──────────────────────────────────────────────────────────
install_pacman() {
    if [ ${#} -eq 0 ]; then return; fi
    run sudo pacman -S --needed --noconfirm "$@"
}

install_aur() {
    local aur_helper
    aur_helper="$(find_aur_helper)"
    if [ -z "$aur_helper" ]; then
        yellow "No AUR helper found (yay/paru). Skipping AUR packages:"
        for p in "$@"; do yellow "  - $p"; done
        MANUAL_NOTES+=("AUR packages (install with yay or paru): $*")
        return
    fi
    run "$aur_helper" -S --needed --noconfirm "$@"
}

install_dnf() {
    if [ ${#} -eq 0 ]; then return; fi
    run sudo dnf install -y "$@"
}

install_apt() {
    if [ ${#} -eq 0 ]; then return; fi
    run sudo apt-get install -y "$@"
}

enable_copr() {
    run sudo dnf copr enable -y "$1"
}

# ── Debian: set up GitHub CLI apt repo ────────────────────────────────────────
setup_gh_apt_repo() {
    if command -v gh &>/dev/null; then return; fi
    header "Setting up GitHub CLI apt repository"
    if $DRY_RUN; then
        dim "(dry-run) would add GitHub CLI apt repo"
        return
    fi
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
}

# ── Main ───────────────────────────────────────────────────────────────────────
case "$DISTRO" in

arch)
    header "Syncing package database"
    run sudo pacman -Sy

    header "Installing CLI packages"
    install_pacman "${PACMAN_CLI[@]}"

    header "Installing fonts"
    install_pacman "${PACMAN_FONTS[@]}"

    if [ "$MODE" = "desktop" ]; then
        header "Installing desktop packages (pacman)"
        install_pacman "${PACMAN_DESKTOP[@]}"

        header "Installing desktop packages (AUR)"
        install_aur "${AUR_DESKTOP[@]}"
    fi
    ;;

fedora)
    header "Updating package metadata"
    run sudo dnf check-update || true  # exits 100 when updates are available — not an error

    header "Installing CLI packages"
    install_dnf "${DNF_CLI[@]}"

    header "Installing fonts"
    install_dnf "${DNF_FONTS[@]}"

    if [ "$MODE" = "desktop" ]; then
        header "Enabling Hyprland COPR"
        for repo in "${COPR_DESKTOP[@]}"; do
            enable_copr "$repo"
        done

        header "Installing desktop packages"
        install_dnf "${DNF_DESKTOP[@]}"
    fi
    ;;

debian)
    setup_gh_apt_repo

    header "Updating apt"
    run sudo apt-get update

    header "Installing CLI packages"
    install_apt "${APT_CLI[@]}"

    header "Installing fonts"
    install_apt "${APT_FONTS[@]}"
    ;;
esac

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
green "==> Package installation complete!"

if [ ${#MANUAL_NOTES[@]} -gt 0 ]; then
    echo ""
    yellow "The following packages need manual installation:"
    for note in "${MANUAL_NOTES[@]}"; do
        yellow "  • $note"
    done
fi

echo ""
echo "Next steps:"
echo "  - Symlink configs : ./install.sh --mode $MODE --distro $DISTRO"
echo "  - tmux plugins    : inside tmux run  prefix + I  (via tpm)"
echo "  - nvim plugins    : open nvim and run  :PlugInstall"
echo ""
