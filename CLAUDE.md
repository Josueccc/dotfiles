# Dotfiles — Claude Guidelines

This repo at `~/.dotfiles` is the single source of truth for all custom environment configuration.

## Golden rule

Every tool we configure together must have its dotfile **here**. Never edit configs in their live locations directly — always edit here and let the symlinks propagate.

## File placement convention

| Tool | Dotfile in this repo | Symlink target |
|------|---------------------|----------------|
| Neovim | `nvim/` | `~/.config/nvim/` |
| tmux | `.tmux.conf` | `~/.tmux.conf` |
| Hyprland | `hyprland/hyprland.lua` (Lua API — new standard) | `~/.config/hypr/hyprland.lua` |
| Rofi | `rofi/` | `~/.config/rofi/` |
| Kitty | `kitty/` | `~/.config/kitty/` |
| Alacritty | `alacritty/` | `~/.config/alacritty/` |
| Fish | `fish/` | `~/.config/fish/` |
| Waybar | `waybar/` | `~/.config/waybar/` |
| Waypaper | `waypaper/` | `~/.config/waypaper/` |
| Wallust | `wallust/` | `~/.config/wallust/` |
| Cava | `cava/config` | `~/.config/cava/config` |
| Swaync | `swaync/` | `~/.config/swaync/` |
| Starship | `starship/starship.toml` | `~/.config/starship.toml` |
| Lazygit | `lazygit/` | `~/.config/lazygit/` |
| btop | `btop/` | `~/.config/btop/` |
| Hyprlock | `hyprland/hyprlock.conf` | `~/.config/hypr/hyprlock.conf` |
| Hypridle | `hyprland/hypridle.conf` | `~/.config/hypr/hypridle.conf` |
| hyprsunset | `hyprland/hyprsunset.conf` | `~/.config/hypr/hyprsunset.conf` |
| hyprqt6engine | `hyprland/hyprqt6engine.conf` | `~/.config/hypr/hyprqt6engine.conf` |
| Qt5ct | `qt5ct/` | `~/.config/qt5ct/` |
| Qt6ct | `qt6ct/` | `~/.config/qt6ct/` |
| Kvantum | `kvantum/` | `~/.config/Kvantum/` |
| KDE globals | `kde/kdeglobals` | `~/.config/kdeglobals` |
| Bash aliases/scripts | `custom.sh` | sourced from `~/.bashrc` / `~/.zshrc` |

## When adding a new tool

1. **Has a config file** → put it in a named subdirectory here (e.g. `starship/starship.toml`) and add the symlink mapping to `install.sh`.
2. **No config file** (CLI tool, package, font, etc.) → add it to `install.md` under the appropriate section so it's remembered for fresh installs.

## install.sh

`install.sh` is the bootstrap script. It uses symlinks (`ln -sf`) so edits here reflect live immediately. Run it after cloning on a new machine. When adding a new symlink mapping, add it to the `SYMLINKS` array inside the script.

## custom.sh

Bash/POSIX aliases and helper functions shared across all environments. Sourced from `~/.bashrc` and `~/.zshrc` by `install.sh`. Fish users: fish has its own function/alias system — put fish-specific stuff under `fish/functions/` or `fish/conf.d/`.

## Dynamic theming (wallust)

Changing the wallpaper re-themes the whole desktop: waypaper runs `wallust/apply-theme.sh` via `post_command`, which runs `wallust` and reloads waybar/swaync/kitty/hyprland. Wallust renders `wallust/templates/*` into `generated-colors.*` files inside `~/.config/{hypr,waybar,rofi,swaync,kitty,alacritty}` — these are **gitignored, machine-specific** files. Style files define a static Catppuccin fallback first and `@import`/`include` the generated file after it (last definition wins). Never hand-edit `generated-colors.*`; run `apply-theme.sh --seed` to restore fallbacks.

## Wallpapers (awww via waypaper)

`waypaper/config.ini` sets `backend = awww`. waypaper 2.9 speaks awww natively: it launches `awww-daemon`, kills whatever painted the background before (swaybg/hyprpaper/swww-daemon) and builds the transition from the `swww_transition_*` keys (yes, still called swww — they drive awww too). **Never set the wallpaper with a bare `awww img`**: the desktop only re-themes because waypaper fires `post_command` → `wallust/apply-theme.sh`. The awww/swaybg branches in `waybar/scripts/wallpaper-picker.sh` exist only for machines without waypaper and call `apply-theme.sh` themselves. `waypaper --restore` in the hyprland autostart does the same thing at login, so the daemon starts itself — nothing else needs to spawn it. Transition types: `fade` (bezier), `wave` (uses `swww_transition_angle`, the swoosh), `grow`/`center`/`any`/`outer` (circle), `wipe`, `random`.

## Night light (hyprsunset)

`hyprland/hyprsunset.conf` holds time-based profiles. hyprsunset applies the profile matching the current time at startup and swaps to the next one when the clock hits it, so no systemd timer is involved — hyprland.lua autostarts it. `hyprland/scripts/nightlight.sh` (bound to `Super+Shift+M`) is a manual override that sticks until `hyprctl hyprsunset reset` or the next profile swap.

## cava in the bar

Arch's waybar is built with `-Dcava=disabled`, so the native `cava` module is unavailable — the bar uses `custom/cava` running `waybar/scripts/cava.sh`. cava's normal terminal output cannot be piped (it emits ANSI escapes unconditionally and asks stdout for a window size), so `cava/config` switches it to `method = raw` + `data_format = ascii`: one digit (0-7) per bar, which the wrapper maps to block glyphs. Colors live in `waybar/style.css` (`#custom-cava`), which inherits the wallpaper palette. Never switch the cava config to `noncurses` without also changing the wrapper.

## install.md

Packages that must be installed manually (or via a package manager) but don't produce a dotfile tracked here. Keep it grouped by category.
