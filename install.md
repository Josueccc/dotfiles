# Packages to install on a fresh machine

These have no dotfile tracked in this repo — install manually or via package manager.

## Core CLI tools

- neovim
- tmux
- ripgrep
- fzf
- fd
- bat (better cat — syntax highlighting, line numbers, git diff)
- eza (better ls — icons, git status, tree view)
- zoxide (smarter cd — tracks frecency, replaces plain cd)
- delta (better git diffs — syntax highlighting, side-by-side)
- tealdeer (fast tldr pages)
- yazi (modern TUI file manager, built in Rust)
- ranger (TUI file manager — legacy fallback)
- btop (system/process monitor — config tracked in btop/)
- starship (cross-shell prompt — config tracked in starship/)
- tar
- zip
- unzip

## Git tools

- git
- lazygit (TUI git client — config tracked in lazygit/)
- gh (GitHub CLI)

## GUI file managers

- thunar (lightweight GTK file manager)
- gvfs (virtual filesystem — trash, MTP, remote mounts)
- tumbler (thumbnail generation service for thunar)
- Ark (archive manager — for extracting zip/tar files in thunar)

## Hyprland ecosystem

- rofi (app launcher — config tracked in rofi/)
- waybar (status bar — config tracked in waybar/)
- swaync (notification daemon — config tracked in swaync/)
- awww (wallpaper daemon — waypaper's `backend = awww`; handles the transitions)
- swaybg (fallback wallpaper daemon — awww's predecessor, kept as a safety net)
- waypaper (wallpaper manager GUI + CLI — config tracked in waypaper/, fires the theming hook)
- swayosd (OSD overlay for volume and brightness indicators — server autostarted in Hyprland)
- grimblast (screenshot, wraps grim + slurp)
- brightnessctl (backlight control)
- wlogout (logout screen)
- pipewire + wireplumber (audio)
- hyprlock (lock screen — config tracked in hyprland/hyprlock.conf)
- hypridle (idle daemon for auto-lock/suspend — config tracked in hyprland/hypridle.conf)
- hyprsunset (blue light filter / night mode — config tracked in hyprland/hyprsunset.conf, time-based profiles, toggle with `Super+Shift+M`)
- hyprpicker (Wayland color picker)
- cliphist (clipboard history daemon for Wayland)
- wl-clipboard (wl-copy / wl-paste CLI clipboard tools)
- xdg-desktop-portal-hyprland (screen sharing + file chooser portals)
- xdg-desktop-portal-gtk (GTK portal fallback for file chooser)
- nwg-look (GTK theme configurator for Wayland — replaces lxappearance)

## Theme & Appearance

- kvantum (Qt theme engine — config tracked in kvantum/)
- qt5ct (Qt5 appearance tool — config tracked in qt5ct/)
- qt6ct (Qt6 appearance tool — config tracked in qt6ct/)
- catppuccin-gtk-theme-mocha (AUR: catppuccin-gtk-theme-mocha)
- bibata-cursor-theme (AUR: bibata-cursor-theme) or catppuccin-cursors

## Authentication & Security

- quickshell (also the polkit auth agent, via `Services.Polkit` — no separate agent package, roadmap 3.2)
- gnome-keyring (credential + SSH key storage)
- seahorse (GUI keyring manager)
- openssh (SSH client + agent)

## Audio & Media

- pamixer (CLI volume control — used in waybar/keybinds)
- playerctl (MPRIS media player control — play/pause/next via keybind)
- pavucontrol (GUI PipeWire/PulseAudio mixer)
- cava (terminal audio visualizer — rendered in the waybar, config tracked in cava/)

## Network

- networkmanager (network management daemon)
- network-manager-applet (nm-applet — system tray icon)
- nm-connection-editor (GUI for VPN and advanced connections)

## Bluetooth

- bluez (Bluetooth protocol stack)
- bluez-utils (bluetoothctl CLI)
- blueman (Bluetooth manager GUI + system tray)

## AI / agent tooling

- opencode (terminal AI agent — config tracked in `opencode/`, installed by its own script
  because there is no distro package: `curl -fsSL https://opencode.ai/install | bash`, which
  drops the binary in `~/.opencode/bin`; that path is already added in `fish/config.fish`.
  The `opencode-model-router` plugin is pulled from npm automatically on first run — no
  manual step. Log in once with `opencode auth login`.)

## Fonts

- JetBrainsMono Nerd Font (terminal, nvim, tmux, rofi)
- noto-fonts (broad Unicode + language coverage)
- noto-fonts-emoji (emoji fallback)
- ttf-font-awesome (icon font for waybar/rofi glyphs)
- Papirus icon theme (used by rofi, qt5ct, qt6ct)
