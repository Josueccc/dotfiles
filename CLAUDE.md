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
| Waypaper | `waypaper/config.ini.template` | `~/.config/waypaper/config.ini` |
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
| GTK3 palette entry | `gtk/gtk-3.0/gtk.css` | `~/.config/gtk-3.0/gtk.css` |
| Firefox | `firefox/userChrome.css` + `userContent.css` + `user.js` | `<profile>/chrome/` (see below) |
| Brave | `brave/apply-brave-theme.sh` | writes `Preferences` directly |
| matugen | `matugen/templates/` + `matugen/config.toml` | (run by `wallust/apply-theme.sh`) |
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

`waypaper/config.ini` is **gitignored** — waypaper rewrites the entire file on every wallpaper change, so tracking it means a dirty tree after every pick. Edit `waypaper/config.ini.template` and re-run `./install.sh --mode desktop` instead; it seeds the live file, keeping the machine's own `wallpaper`/`backend`/`folder`/`monitors`/style paths and taking everything else from the template. With `use_xdg_state = True` the volatile keys live in `~/.local/state/waypaper/state.ini` and the live config stays stable, so nothing re-dirties the tree.

`backend = awww`. waypaper 2.9 speaks awww natively: it launches `awww-daemon`, kills whatever painted the background before (swaybg/hyprpaper/swww-daemon) and builds the transition from the `swww_transition_*` keys (yes, still called swww — they drive awww too). **Never set the wallpaper with a bare `awww img`**: the desktop only re-themes because waypaper fires `post_command` → `wallust/apply-theme.sh`. The awww/swaybg branches in `waybar/scripts/wallpaper-picker.sh` exist only for machines without waypaper and call `apply-theme.sh` themselves. `waypaper --restore` in the hyprland autostart does the same thing at login, so the daemon starts itself — nothing else needs to spawn it. Transition types: `fade` (bezier), `wave` (uses `swww_transition_angle`, the swoosh), `grow`/`center`/`any`/`outer` (circle), `wipe`, `random`.

## ## Idle / lock (hypridle)

`hyprland/hypridle.conf` is a ladder: dim (5 min) → lock (15) → dpms off (25) → suspend (45). Keep suspend last — an earlier suspend will pull the machine out from under a long build while the screen is still lit. hypridle 0.1.8 is the newest on Arch and **rejects** the newer `dpms` and `check_interval` listener keys, so the display-off step is a `hyprctl dispatch dpms off` on a timer rather than a native DPMS listener. Verify a change with `hypridle -c ~/.config/hypr/hypridle.conf -v` (it prints each registered rule; the "already running" error is expected while the real daemon is up).

## GTK theming (matugen, GTK3 only — GTK4 is a known dead end)

**GTK3 follows the wallpaper.** `wallust/apply-theme.sh` runs `matugen` alongside
wallust, writing `~/.config/gtk-3.0/colors.css` from `matugen/templates/breeze.css`.
`gtk/gtk-3.0/gtk.css` is a one-line `@import 'colors.css'` — that import is the whole
mechanism. Verified: `deer-forest.jpg` → `#141318`, `serial_experiments_lain.png` →
`#111318`, same window, only the wallpaper changed.

Why matugen and not wallust for GTK: `gtk-theme-name=Breeze` uses ~84
differently-named variables (`theme_base_color_breeze`, `insensitive_fg_color_breeze`, …)
rather than adwaita's `accent_color`/`window_bg_color`. matugen's stock GTK template emits
the adwaita names, which Breeze ignores, so `matugen/templates/breeze.css` is a
hand-written template mapping Material tokens onto Breeze's names. It covers 84/84.

The payoff is in the **accents**, not the surfaces. Stock Breeze hardcodes
`theme_selected_bg_color_breeze #315bef` — a bright blue unrelated to any wallpaper, and
the most visible colour in a file manager. matugen derives it (`#473f77` under
deer-forest). Surfaces only shift `#242424` → `#141318`, which is nearly invisible; an
earlier note claiming "the visual payoff is small" was measured on surfaces and missed this.

**GTK4 is not wired up, and I could not make it work — don't retry blind.** `gnome-calendar`
is the only real GTK4 app installed (blueman-manager is a Python script, so it is GTK3 via
PyGObject; gnome-disks is GTK3 too), so the blast radius is one app. Findings:

- `~/.config/gtk-4.0/gtk.css` is a symlink straight into
  `/usr/share/themes/catppuccin-mocha-sapphire-standard+default/gtk-4.0/gtk.css`, which
  contains **no `@import`** — so `~/.config/gtk-4.0/colors.css` was never read by
  anything. It is a dead file.
- GTK4 honours `@import 'x.css'` but **silently ignores `@import url('x.css')`**. Verified
  by pixel-sampling gnome-calendar: the `url()` form did nothing, the bare-quoted form
  worked. Easy trap.
- Simply pointing that symlink at a file which imports `colors.css` **does not work**.
  `gtk-dark.css` is a separate file GTK4 loads at *higher* priority than `gtk.css`, so the
  catppuccin palette it defines always wins. Removing the `gtk-dark.css` symlink got
  closer, but overriding `window_bg_color` from the user file still did not take, and a
  forced-magenta probe proved the override never reached the widget.
- This is consistent with the theme defining the names itself: Breeze does **not** define
  `window_bg_color`, but every `catppuccin-*` theme does, so there is nothing to override.

GTK4 is left exactly as found (both symlinks to the catppuccin theme). To revisit it, the
promising route is a custom *theme* directory that wraps the catppuccin one rather than
fighting its load order — not another user-level `gtk.css`.

## Qt6 theming (`kde`, not hyprqt6engine or qt6ct)

`hyprland/hyprland.lua` sets **`QT_QPA_PLATFORMTHEME=kde`** — that is
`KDEPlasmaPlatformTheme6.so` from `plasma-integration`. It reads `~/.config/kdeglobals`
and hands Qt the `[Colors:*]` palette, so `kde/kdeglobals` themes every Qt6 app. Dolphin
(a KF6 app) samples `#1e1e2e` under it, which is the Catppuccin Mocha base.

Three traps here, each of which cost a debugging session:

- **Do not use `hyprqt6engine`.** The packaged 0.1.0 links against `libhyprutils.so.12`
  while the system ships 0.14.2 (soname `.13`), so `libhyprqt6engine.so` fails to
  `dlopen`, Qt silently falls back to its built-in **light** palette, and every Qt6 app
  is a **white window on a dark desktop** — no error anywhere, because
  `hyprqt6engine.conf` is never read. Editing it changes nothing, which sends you
  hunting in the wrong file. Check with
  `ldd /usr/lib/qt6/plugins/platformthemes/libhyprqt6engine.so`.

- **Do not use `qt6ct` either, even though its plugin loads fine.** It themes plain Qt6
  apps correctly, but KF6 apps override its palette and stay light. Same Dolphin window,
  pixel-sampled: `qt6ct` → `#eff0f1`, `kde` → `#1e1e2e`. pavucontrol is *identical*
  under both, which is exactly why a pavucontrol-only check hides the bug — **always
  verify with a KF6 app (Dolphin), not just a plain Qt6 one.** `qt6ct/qt6ct.conf` is
  kept as a fallback but is not the theme driver.

- **Env changes need a relogin.** `hl.env` is applied when Hyprland parses its config at
  startup; editing `hyprland.lua` later does not change the running session. Compare
  `ps -o lstart= -p $(pgrep -x Hyprland)` with the file's mtime. That is how a correct
  fix can sit in the repo for hours looking broken. This build has no `hyprctl setenv`
  ("unknown request"), so it cannot be patched live.

Two more traps in this area:
- **qt6ct's `dusk.conf` is a LIGHT scheme**, despite the name. `qt6ct/qt6ct.conf` points at `qt6ct/colors/catppuccin-mocha.conf` instead, which is the Catppuccin Mocha palette written for qt6ct's fixed 22-value ColorScheme layout.
- `kde/kdeglobals` shipped light Breeze values in its `[Colors:*]` sections; those are now dark Catppuccin, and `[KDE] ColorScheme` names the scheme. It really is honoured — set `BackgroundNormal=255,0,255` and Dolphin turns magenta.

## Night light (hyprsunset)

`hyprland/hyprsunset.conf` holds time-based profiles. hyprsunset applies the profile matching the current time at startup and swaps to the next one when the clock hits it, so no systemd timer is involved — hyprland.lua autostarts it. `hyprland/scripts/nightlight.sh` (bound to `Super+Shift+M`) is a manual override that sticks until `hyprctl hyprsunset reset` or the next profile swap.

## cava in the bar

Arch's waybar is built with `-Dcava=disabled`, so the native `cava` module is unavailable — the bar uses `custom/cava` running `waybar/scripts/cava.sh`. cava's normal terminal output cannot be piped (it emits ANSI escapes unconditionally and asks stdout for a window size), so `cava/config` switches it to `method = raw` + `data_format = ascii`: one digit (0-7) per bar, which the wrapper maps to block glyphs. Colors live in `waybar/style.css` (`#custom-cava`), which inherits the wallpaper palette. Never switch the cava config to `noncurses` without also changing the wrapper.

Two things in that config that look wrong but aren't: `bar_delimiter` must stay a **printable** character (setting it to `0` means "emit a NUL byte", not "no separator" — the wrapper strips non-digits anyway, which is why it degrades to clean bars rather than garbage), and `noise_reduction` needs to be lowish (60) or the bars barely move on anything but loud audio. To check the bars are actually reacting, play a tone with `paplay /usr/share/sounds/alsa/Front_Center.wav` — `pactl play-file` does not exist.

## Firefox theming (wallust → Design System tokens)

Firefox 156 follows the wallpaper. `wallust/templates/colors-firefox.css` writes
`firefox/generated-colors.css`, and `firefox/link-profile.sh` symlinks four files
into the profile. The `chrome/` subdirectory is the whole mechanism, and four
things about it are all silent failures:

- **The files go in `<profile>/chrome/`, not the profile root.** Overwhelmingly
  most guides say the root, and so does the comment in libpref's `all.js`
  ("checking the user profile directory"). Both are wrong:
  `nsXREDirProvider.cpp` appends `chrome` to `NS_APP_USER_CHROME_DIR`, and
  `GlobalStyleSheetCache::InitFromProfile` then appends the two filenames.
  Proven with a two-colour probe — magenta in the root, cyan in `chrome/` —
  which rendered 213,082 cyan pixels and 0 magenta.
- **The profile dir is a random hash** (`2z7f38dl.default-release`) and this
  machine keeps profiles in `~/.config/mozilla/firefox`, not `~/.mozilla`.
  `link-profile.sh` resolves it from `profiles.ini` on every run, so the links
  survive the profile being recreated.
- **`toolkit.legacyUserProfileCustomizations.stylesheets` is still required**, still
  defaults to false, and fails silently — no warning, no error. Also note
  `userChrome.css` is never read in Safe Mode, which is the intended escape hatch.
- **`!important` is mandatory on every declaration.** The skin declares its tokens
  inside a 10-layer `@layer` preamble (`tab.tokens.css:8`), and a declaration
  inside a cascade layer loses to every unlayered one — so an unlayered
  user-origin normal declaration is beaten by a layered UA one regardless of
  specificity. You cannot fix this from the user sheet; `@layer` reordering is
  inert because the UA sheet fixes the layer order first.

**Use the Design System tokens, not `--lwt-*`.** The old names are not merely
deprecated, they are unreachable: the skin consumes `--lwt-*` only inside a
`:root[lwtheme]` block, and `lwtheme` is only set when a WebExtension theme is
installed. Setting `--lwt-accent-color` by hand does nothing. `--toolbar-bgcolor`,
`--tab-selected-bgcolor` and `--urlbar-box-bgcolor` have **zero** definitions and
zero uses in the shipped jars. Live names: `--toolbar-background-color`,
`--tab-background-color-selected`, `--tab-selected-textcolor`,
`--sidebar-background-color`, `--urlbar-box-background-color`, and
`--tab-line-selected-color` for the active-tab accent (the selected tab's
background is a *stacked image* on `.tab-background`, not a `background-color`, so
a naive override does nothing).

Beware `--tab-bg` / `--tab-text-color`: those are real but belong to
**pdf.js**'s bundled `viewer.css`, not to browser chrome. Grepping `omni.ja` finds
them first and they look like a perfect answer.

**`@import` must be the first thing in the file.** waybar's `style.css` gets away
with importing after its rules because GTK's CSS parser is lenient; Firefox uses a
spec-compliant parser and silently drops an out-of-order `@import`. That is why the
palette is split into `fallback.css` (tracked) and `generated-colors.css`
(generated), both imported at the top of `userChrome.css`/`userContent.css`, rather
than a fallback block followed by an import.

**about: pages are content documents**, so they resolve against a different half of
the design system. The hook is the primitive ramp, not the widgets:
`about:preferences` sets `--background-color-canvas: light-dark(var(--color-gray-0),
var(--color-gray-90))` and paints from it. Overriding `--color-gray-*` and
`--color-accent-primary` re-themes every internal page without naming a selector.
Reachable: preferences, addons, newtab, config, logins, profiles, about:blank.
**`about:downloads` is not** — it is not a normal content docshell, so don't try.

### The accent is `color7`, and that was measured, not chosen

The obvious pick, `color4`, fails on both counts. On `deer-forest.jpg`:

| pair | ratio | needs | |
|---|---|---|---|
| `color4` as link text on canvas | 3.43 | 4.5 | FAIL |
| `color4` as focus ring on nav bar | 1.94 | 3.0 | FAIL |
| `color6` as focus ring on nav bar | 4.68 | 3.0 | pass |
| `color7` as focus ring on nav bar | 8.64 | 3.0 | pass |

Sweeping candidate mappings over 30 wallpapers and re-checking every pair each
time: `color6` 23/30, `color7` 28/30, `color7` for the muted tier 30/30. `color6`
drifts close to `color0` on low-chroma images, which is what the failures were. The
winning config also collapsed the text ramp to two tones — body text `foreground`,
everything de-emphasised `color7` — which is the honest outcome: a 16-colour
wallpaper palette only guarantees its two extremes. A three-tier ramp looked
tidier and failed. The same sweep is worth re-running after touching the mapping:
`/tmp/opencode/verify.py` re-checks the generated file and exits non-zero on any
pair below its threshold.

## Brave theming (one seed colour — M154 deleted the rest)

`brave/apply-brave-theme.sh` writes a theme into Brave's `Preferences`. This is
much smaller than everything else in the pipeline, and not by choice.

**`brave --version` prints `154.1.96.59`, and 1.96 is the *Chromium milestone*, not
Brave's version.** This is Brave 154 / Chromium 154. Read it as "1.96" and you go
looking for theme features that were deleted twenty milestones ago. Verified
against `/opt/brave-bin/brave` (note `/usr/bin/brave` is a bash wrapper — probing
*that* with `strings` returns zero for everything, which looks like confirmation
of anything you hoped for):

```
frame_color              0        chrome.theme              0
ntp/background_color      0        user_color_theme_id       1
autogenerated.theme.color 1       browser.theme.color_scheme2 1
```

The multi-colour native theme JSON is **deleted** — not legacy, not deprecated,
`chrome/theme/` returns 404 and neither `_api_features.json` nor
`_permission_features.json` contains `theme`. The `chrome.theme` WebExtension API
is gone too, so there is no extension route either. M154 accepts **one ARGB seed
colour** plus a variant enum (`kSystem/kTonalSpot/kNeutral/kVibrant/kExpressive`)
and derives every surface via `ui::ColorProvider`. A 16-colour wallpaper palette
is simply not expressible.

The prefs are unprotected (no MACs in this profile) and read at startup by
`ThemeService::InitFromPrefs`, so a hand-edit works. Three traps:

- **The colour must be a JSON *signed 32-bit int*.** `"#7C5CFF"` is silently
  ignored. This is the #1 cause of "I wrote it and nothing happened."
- **Never write while Brave is running.** `PrefService` rewrites the whole file on
  a ~10s debounce and unconditionally on exit. The script refuses to run.
- Prefer the **`autogenerated_theme_id`** branch: it is the only one that calls
  `SwapThemeSupplier()` explicitly. `autogenerated.theme.policy.color` does *not*
  work by hand-editing — `UsingPolicyTheme()` checks `IsManagedPreference()`.

Verify by pixel-sampling a screenshot, not by re-reading the file, and do not
assert the rendered colour equals the seed — the mixer transforms it.

Discord is deliberately untouched: it exposes no theming surface at all, and the
only route is a loader that patches `app.asar`, which re-breaks on every update.

## install.md

Packages that must be installed manually (or via a package manager) but don't produce a dotfile tracked here. Keep it grouped by category.
