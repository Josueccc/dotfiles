# Dotfiles — Claude Guidelines

This repo at `~/.dotfiles` is the single source of truth for all custom environment configuration.

## Golden rule

Every tool we configure together must have its dotfile **here**. Never edit configs in their live locations directly — always edit here and let the symlinks propagate.

## File placement convention

| Tool | Dotfile in this repo | Symlink target |
|------|---------------------|----------------|
| Neovim | `nvim/` | `~/.config/nvim/` |
| tmux | `.tmux.conf` | `~/.tmux.conf` (palette → `~/.config/tmux/`, generated) |
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
| opencode | `opencode/opencode.json` + `opencode/cli.json` | `~/.config/opencode/` (file by file) |
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

Changing the wallpaper re-themes the whole desktop: waypaper runs `wallust/apply-theme.sh` via `post_command`, which runs `wallust` and reloads waybar/swaync/kitty/hyprland. Wallust renders `wallust/templates/*` into `generated-colors.*` files inside `~/.config/{hypr,waybar,rofi,swaync,kitty,alacritty,quickshell}` — these are **gitignored, machine-specific** files. Style files define a static Catppuccin fallback first and `@import`/`include` the generated file after it (last definition wins). Never hand-edit `generated-colors.*`; run `apply-theme.sh --seed` to restore fallbacks.

The quickshell one is the exception to "reload the app": it is a `FileView` with `watchChanges`, so it repaints from the new JSON with **no restart and no reload line in `apply-theme.sh`**. It is the only consumer in the pipeline that never needs to be poked.

`wallust/templates/colors-quickshell.json` is strict JSON with **no comments** — its consumer is a `JsonAdapter`, and JSON has no comment syntax that survives parsing. The reasoning lives in `wallust/wallust.toml` next to the entry instead. Its palette names and source indices are deliberately identical to `colors-waybar.css` so the bar and the dashboard cannot drift apart; change one, change both.

## Wallpapers (awww via waypaper)

`waypaper/config.ini` is **gitignored** — waypaper rewrites the entire file on every wallpaper change, so tracking it means a dirty tree after every pick. Edit `waypaper/config.ini.template` and re-run `./install.sh --mode desktop` instead; it seeds the live file, keeping the machine's own `wallpaper`/`backend`/`folder`/`monitors`/style paths and taking everything else from the template. With `use_xdg_state = True` the volatile keys live in `~/.local/state/waypaper/state.ini` and the live config stays stable, so nothing re-dirties the tree.

`backend = awww`. waypaper 2.9 speaks awww natively: it launches `awww-daemon`, kills whatever painted the background before (swaybg/hyprpaper/swww-daemon) and builds the transition from the `swww_transition_*` keys (yes, still called swww — they drive awww too). **Never set the wallpaper with a bare `awww img`**: the desktop only re-themes because waypaper fires `post_command` → `wallust/apply-theme.sh`. The awww/swaybg branches in `waybar/scripts/wallpaper-picker.sh` exist only for machines without waypaper and call `apply-theme.sh` themselves. `waypaper --restore` in the hyprland autostart does the same thing at login, so the daemon starts itself — nothing else needs to spawn it. Transition types: `fade` (bezier), `wave` (uses `swww_transition_angle`, the swoosh), `grow`/`center`/`any`/`outer` (circle), `wipe`, `random`.

## Displays (hyprland.lua MONITORS)

Two outputs: the laptop panel `eDP-1` (1920x1080@120) and the Samsung Odyssey G5 `HDMI-A-1` (2560x1440@120). Both at scale 1.25.

**The Samsung's refresh rate is set on the monitor, not here.** Its EDID is rewritten by two OSD settings: the HDMI version (1.4 caps it at 60) and a separate **Refresh Rate** option (60/120/144), which a settings reset (brightness jumps to max) puts back to **60** — the EDID then says `50-75 Hz, max dotclock 250 MHz` even in HDMI 2.0 mode. The config stays `mode = "preferred"`, which follows whatever the monitor offers. **Never pin a mode the EDID lacks**: Hyprland invents CVT timings, nvidia rejects them with `EINVAL`, and aquamarine retries forever on a black output (6,595 failed commits in one test). The port is *not* limited to HDMI 1.4 bandwidth — an earlier conclusion that it was came from Hyprland's **stale** mode list (switching the HDMI version in the OSD sends no hotplug; replug the cable) plus a `sort -u` that collapsed the 2560x1440 lines. Check what the monitor really offers with `edid-decode /sys/class/drm/card1-HDMI-A-1/edid` and `modetest -M nvidia-drm -c`. **144 Hz (580 MHz) does not hold** on this link: the flip never completes and the monitor drops and reconnects in a loop. **120 Hz (498 MHz) held** — 60s with zero disconnects. FreeSync in the OSD is useless here: it is AMD's HDMI VRR and the connector is on the NVIDIA GPU (`incapable of vrr`); leave it off.

**Both outputs get explicit positions; `auto` is banned for the panel.** The Samsung is pinned to `0x0`. The panel is `2048x0` with the Samsung present and `0x0` alone, and `place_panel()` (registered on `monitor.added`, `monitor.removed` and `hyprland.start`) switches between the two, deferred 500ms with `hl.timer`. The earlier design left the panel on `position = "auto"`, and every move `auto` makes on its own **moves the monitor but not its layer surfaces**: after an unplug, eDP-1 sat at 0x0 while waybar and the awww wallpaper stayed at x=2048 (`hyprctl layers`), i.e. a bare panel with both processes alive; replug and resume did the reverse. A rule whose *value* changes forces a reconfigure that does re-arrange the layers, while re-applying an identical rule is a no-op, so the panel must only ever move through a changed rule. Check with `hyprctl layers`, not `hyprctl monitors` — the monitor position was always right. **`hl.timer` needs `type = "oneshot"` or `"repeat"`**: without it the call returns nil and never fires, silently. A wildcard rule (`output = ""`) stays first in the block for anything else that gets plugged in — a later specific rule overrides it, which is why the order matters.

**"Main" also means where focus starts**, and that is not automatic: the active workspace follows the focused monitor, so a boot with both up drops you on the laptop panel and the first window opens on the wrong screen. `focus_primary()` dispatches `hl.dsp.focus({ monitor = "HDMI-A-1" })` — the working form on this Lua build, per the `hyprctl` note below — and it runs from `place_panel()` on `hyprland.start` and `monitor.added`, so replugging hands focus back to the Samsung without a reload. The `hl.get_monitor("HDMI-A-1")` guard is not decoration: focusing an absent output logs `monitor not found` and leaves focus untouched, which is the right outcome anyway, but it would warn on every lid open.

Verified, not assumed — `ok` is not evidence (see below):

- both connected → `HDMI-A-1 … at 0x0`, `eDP-1 … at 2048x0`, `hyprctl configerrors` empty
- unplug path, simulated with `hyprctl eval "hl.monitor({output='HDMI-A-1', …, disabled=true})"` → `eDP-1` moves to `0x0` by itself (that was the `auto` design; it moved the monitor and stranded the layers — see above). Note `hl.config({monitor={{…}}})` returns `ok` and changes **nothing** here; the runtime form is `hl.monitor({...})`. `hyprctl keyword` is dead on this build ("can't work with non-legacy parsers").
- `monitor.added` control test: focus eDP-1 by hand, then `hyprctl output create headless` — a new output does not take focus on its own (`focused: no`), and focus is on `HDMI-A-1` afterwards, so the handler fired. `hyprctl output remove HEADLESS-N` to undo. Checking a focused monitor: `hyprctl repl "for _,o in ipairs(hl.get_monitors()) do if o.focused then print(o.name) end end"`. **Do not use `output create` again** — the compositor died and the session restarted within a minute of the fake headless output being added and removed, and nothing in `hyprland.log` explains it. Suspect the headless backend teardown, unproven. `disabled = true` on a real output has never crashed anything and is the safe way to simulate a cable.

Waybar is `output: "all-outputs"`, but it does **not** simply follow the layout: its layer surface keeps its old coordinates unless the monitor move came from a changed rule. That is what `place_panel()` is for.

### Workspaces 1-5 on the Samsung, 6-10 on the panel

`hl.workspace_rule({ workspace = "<id>", monitor = "<name>" })` per workspace, via `assign_workspaces()` in the WINDOWS AND WORKSPACES section. `default = true` on ws 1 (Samsung) and ws 6 (panel) is what decides the workspace each monitor comes up on.

**One rule per workspace ID. A range is silently ignored** — no config error, no warning, and the workspaces go somewhere else. Both range spellings parse cleanly and bind nothing:

- `workspace = "1-5"` — not a selector at all
- `workspace = "r[1-5]"` — a real selector, but selectors "can only match existing workspaces", so it is evaluated against what already exists and never binds a workspace *being created*

Proved by creating fresh workspaces and reading `hyprctl workspaces`: a range bound to `HDMI-A-1` still put a brand-new ws 25 on `eDP-1`, as did one under `r[60-69]`. A bare numeric id binds at creation — ws 40 → Samsung and ws 41 → panel, both first try. Note this is the opposite of the trap in the `hyprctl` section: here the *rejected-looking* syntax (a range) is the one that fails quietly, and `hyprctl workspacerules` lists it happily, monitor and all. Read `hyprctl workspaces` → `monitorID` (1 = Samsung, 0 = panel) instead.

**Both halves are required.** An unassigned workspace does not default to "the other monitor" — it lands on whichever monitor holds focus, and focus starts on the Samsung, so with only the 1-5 half written all ten pile up on the external display.

**The binding is applied at workspace *creation* and never revisited.** A workspace that already exists on the wrong monitor stays there — not on `reload`, not when a window is moved onto it, not when the monitor is disabled and re-enabled. So editing this config only affects workspaces that do not exist yet, and there is no `destroyworkspace` dispatcher in this build to clear the old ones; empty workspaces also survive a config reload rather than being reaped. **A fresh login is the only way to re-apply a changed binding.** This bit during development: workspaces 1 and 10 were created before the rules existed and stayed stubbornly on the wrong monitor. The saving grace is that a `reload` *does* release most empty workspaces, so the wrong-monitor set usually shrinks to a handful before you notice.

Hotplug is unaffected by that, because the monitor's own rules are re-evaluated on every output change. Verified by disabling the Samsung: 1-5 fall back to the panel with no errors, eDP-1 sits at 0x0, and on re-enable ws 2 and 5 came back to the Samsung while the panel came up on its ws 6 default.

**Stale `HYPRLAND_INSTANCE_SIGNATURE` breaks every `hyprctl` call, silently.** `hyprctl` resolves the compositor through that variable and exits with "Couldn't connect to ..." when it points at a dead instance. A compositor restart leaves its old signature directory in `/run/user/1000/hypr/` *and* every long-lived shell keeps the dead one exported, so `hyprctl monitors` returns nothing and `hyprctl eval ...` does nothing at all — no error where a person would see it. This is not theoretical: it is why the shell in a session that predates a Hyprland restart needs `export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr/ | head -1)`, and a directory with no `.socket.sock` in it is a dead instance's leftover. A live one always has `.socket.sock`; pick the newest that does.

## ## Idle / lock (hypridle)

`hyprland/hypridle.conf` is a ladder: fade (5 min) → lock (15) → dpms off (25) → suspend (45). Keep suspend last — an earlier suspend will pull the machine out from under a long build while the screen is still lit.

**The fade is `hyprland/scripts/dim-ramp.sh`, not a `brightnessctl set`.** Two reasons, both found by running the old line: `brightnessctl set 10` is a **raw sysfs value**, and this panel's max is 65535, so the old config asked for 0.015% — a black screen at five minutes — while its own comment said it was dimming. And a single `set` is a step change, which reads as a glitch rather than as dimming. The script takes a real *percentage*, converts it against the device max, and interpolates with a **smoothstep** (a linear fade spends most of its time in the invisible tail and looks like a stall). It writes its pid to `$XDG_RUNTIME_DIR/hypr-dim-ramp.pid` because `pkill -f dim-ramp` matches the *calling shell*; `wake` kills that pid and restores, and refuses to start a second ramp that would save an already-dimmed level as the user's own. The 10% floor lives in the script's default (`ramp "${1:-45}" "${2:-10}"`), not in `hypridle.conf`, which passes no arguments — raise it there, or pass `dim 45 20`, if the lock screen is ever unreadable in daylight. That floor is unverified: judging it needs someone standing in front of the screen in real light.

**This machine's `hyprctl` is the Lua build.** `hyprctl dispatch <name> <args>` is rewritten to `hl.dispatch(...)` and fed to Lua, so the classic form dies with a parse error: `hyprctl dispatch dpms off` → `')' expected near 'off'`, and `hyprctl dispatch exit` → `expected a dispatcher`. The working form of any dispatcher is `hyprctl eval "hl.dispatch(hl.dsp.dpms({ action = 'off' }))"`; `hyprctl eval "hl.exec_cmd('…')"` runs a command. **The dpms-off step had been silently broken for this reason** — the ladder's 25-minute screen blank never once ran, and nothing logged an error where anyone would see it.

Three traps in that API, all of which cost real time here:

- **`hl.dsp.dpms` takes a table, and the string form is a TOGGLE.** `hl.dsp.dpms('on')` and `hl.dsp.dpms('off')` ignore the string and flip every output. Proved 2026-09-30: with eDP-1 off and HDMI-A-1 on, `dpms('on')` swapped them; with both on, `dpms('on')` turned both **off**. `{ action = 'on' }` / `{ action = 'off' }` do what they say and are idempotent. The 25-minute blank "worked" only because the screens were on when it fired; the wake path, doing the same toggle, could not wake reliably and blanked the one screen that was lit.
- **The `hl.dispatch(...)` wrapper is not optional.** `hl.dsp.dpms({...})` on its own only *builds* a dispatcher object and blanks nothing.
- **`ok` is not evidence.** Every `hyprctl eval` of a dispatcher returns `ok` — including `hl.dispatch(hl.dsp.global("totally_bogus_name"))`, and including a dispatcher that was merely constructed and never run. There is no validation at the binding layer either: `hl.dsp.global(12345)` returns a Dispatcher happily. Prove a compositor change with observable state — `hyprctl monitors | grep dpmsStatus` (1 = on, 0 = off), `hyprctl devices | grep "active keymap"`, `hyprctl binds` — never with a return code.

**`Super+space` is `hyprland/scripts/toggle-kb-layout.sh`, not a dispatcher call.** The bind used to be `hyprctl dispatch switchxkblayout all next`, which is one of the parse errors above, so the key did nothing at all. The obvious repair — driving the Lua `switchxkblayout` dispatcher from the shell — is not verifiable: the constructors never fail, so you cannot tell a correct call from a typo, and four plausible shapes all reported success while the keymap never moved. So the script rewrites the layout list instead, via `hl.config({input={…}})`, which *is* observable. **`input:kb_layout` and `input:kb_variant` are parallel lists and must move together**; with `kb_variant = "intl,"` they are the only thing distinguishing the two layouts, so rotating one alone puts the `intl` variant on the Spanish layout and it types `ñ` as `~`. Verified by `hyprctl devices`: `English (US)` ↔ `Spanish (Latin American)`, both ways. The layout is **standard US**, not US-international — `"intl,"` makes the accented characters dead keys, easy to forget you are holding one. The toggle is **serialised with `flock`**: it is a read-modify-write, so two presses arriving together could both read the same list and both write the same answer, losing one. The race was intermittent (~1 press in 3), which reads as a flaky key rather than a bug; under the lock the second press waits and reads what the first wrote, so every press toggles. The script also keeps a stock Hyprland working by falling back to the classic dispatcher when `hyprctl --help` has no `eval`.

**`Super+M` logout prefers `hyprshutdown`** (it stops apps cleanly) and only then falls back to `hyprctl eval "hl.dispatch(hl.dsp.exit())"`, then to the classic `hyprctl dispatch exit`. That whole chain was previously the parse error above and was masked only because `hyprshutdown` exists here and short-circuits it. The `exit` dispatcher is the one call in this repo that cannot be tested without ending the session, so it stays unverified on purpose.

`hyprctl reload` re-reads the config without duplicating autostarted daemons (checked: waybar and hypridle pids unchanged) and `hyprctl configerrors` is the check for a bad edit. `luac -p hyprland/hyprland.lua` catches a syntax error before you reload. What a reload does **not** apply is `hl.env` — see the relog trap below.

**hypridle has no reload** — it reads its config once at startup, so a config change needs `kill $(pgrep -x hypridle)` and a fresh start (`hyprctl eval "hl.exec_cmd('hypridle')"`; plain `hyprctl dispatch exec hypridle` does not work here). Verify a config with `timeout 3 hypridle -c ~/.config/hypr/hypridle.conf -v` — it prints each registered rule and the "Is hypridle already running?" error is expected while the real daemon is up. **The `-v` run does not exit**, so it needs the `timeout`, and a bare `… | head` only works because `head` closes the pipe.

hypridle 0.1.8 is the newest on Arch and **rejects** the newer `dpms` and `check_interval` listener keys, so the display-off step is a timer calling `hyprctl eval` rather than a native DPMS listener. It does run everything through `/bin/sh -c`, which is why `$HOME` expansion and `;` work in those command strings. (On a stock Hyprland, where `hyprctl` is the classic build, the eval form does not exist — put `hyprctl dispatch dpms off` back for that machine.)

**Check the live link, not the repo.** Until 2026-09-30 `~/.config/hypr/scripts/wake-monitors.sh` did not exist: the script was in the repo and in `install.sh`, but `install.sh` had not been re-run, so every `after_sleep_cmd` and `on-resume` that named it failed silently (hypridle's `sh -c` output goes nowhere) and the screens stayed off after the 25-minute blank. After adding a script, run `./install.sh` or link it by hand, and check with `ls -l ~/.config/hypr/scripts/`. `wake-monitors.sh` now logs an `invoked (...)` line on every run, so `journalctl -b -t wake-monitors` being **empty** after a wake means it was never called.

**`dpmsStatus: 1` does not mean there is a picture.** After a resume on 2026-09-29 with the cable in, the Samsung reported `dpmsStatus: 1` and stayed black: aquamarine logged `drm: Cannot commit when a page-flip is awaiting` — the NVIDIA secondary GPU never delivered a flip completion, so no frame was committed again. The observable test is a screencopy: `timeout 3 grim -o HDMI-A-1 - >/dev/null` hangs (124) on a stuck output and returns at once on a live one. A `dpms` off/on cycle cleared it, verified live. `wake-monitors.sh` now runs that check on every resume and cycles dpms only when an output times out (~0.5s when healthy); it logs to `journalctl -t wake-monitors`. Background: the HDMI port is wired to the NVIDIA GTX 1650 (`card1`) while Hyprland renders on the AMD iGPU (`card2`, primary), so every Samsung frame is a cross-GPU blit — suspend with the cable **out** resumes cleanly, with it **in** it is the failure. `hyprland/scripts/resume-trace.sh` copies `hyprland.log` (tmpfs, lost on a hard reset) into `journalctl -t resume-trace` around each suspend.

**The screen-on half of the ladder is `hyprland/scripts/wake-monitors.sh`, not a `dpms on` one-liner.** A resume on 2026-09-27 left both outputs black and the session had to be rescued over a TTY. The cause was *not* the quickshell lock, which is the obvious suspect and was innocent: no `quickshell -p .../quickshell/lock` process was running, `loginctl show-session -p LockedHint` said `no`, and `hyprctl clients` listed only the kitty windows. `hyprctl monitors` said `dpmsStatus: 0` on both — the ladder's own 25-minute blank had simply never been undone.

Two independent ways the old `after_sleep_cmd = hyprctl eval "hl.dispatch(hl.dsp.dpms('on'))"` could do nothing, with no output anywhere to say so:

- **It trusted the environment.** A stale `HYPRLAND_INSTANCE_SIGNATURE` (see the Displays section — that is exactly what killed it here) makes every `hyprctl` call a no-op. The script re-resolves the signature from `$XDG_RUNTIME_DIR/hypr`, preferring the newest directory that still has a `.socket.sock`.
- **It raced the DRM re-arm.** logind runs `after_sleep_cmd` while the outputs are still being re-armed out of S3, and the kernel re-blanks the CRTCs afterwards — aquamarine's log has the whole dance in it ("Rechecking CRTCs", "eDP-1 is disabled, releasing crtc 85", the slots reassigned). A single dispatch issued in that window is overwritten. Hence the settle delay, the retries, and the `dpmsStatus` check instead of an assumed success.

Verified: with a deliberately poisoned signature (`deadbeef_dead_0000`) and both monitors off, the script recovered both in ~2s. With the screens already on it returns in ~0.5s (the frame check) and dispatches nothing, so putting it on the 25-minute listener's `on-resume` as well as `after_sleep_cmd` is cheap. **Real suspend with the HDMI cable in, verified 2026-09-30:** resume at 00:12:06 with both outputs reporting `dpmsStatus: 1`, frame check timed out on `HDMI-A-1` at 00:12:10, dpms cycle, `recovered` at 00:12:16, lock screen up, layers aligned. The visible cost is a ~6s black-then-blink on both screens after a docked resume. If it ever fails, the script `notify-send`s and logs to `journalctl -t wake-monitors`.

**The quickshell lock must restart PAM after every failure.** `PamContext` runs one attempt per `start()`; after a wrong password it completes and goes inactive. The first version started it only from `secure` and `submit()` returned early on `!pam.active`, so after one typo every later password was dropped and the only way out was a TTY (2026-09-30). `quickshell/lock/shell.qml` now restarts it after a failure and starts one on demand for a password typed while none is running. `misc.allow_session_lock_restore = true` in `hyprland.lua` lets a replacement lock client take over a dead or stuck one instead of leaving Hyprland's "lockscreen died" screen. To replace one from a TTY, launch it **through the compositor** — `hyprctl eval "hl.exec_cmd('$HOME/.config/hypr/scripts/lock.sh')"` — because a TTY shell has no `WAYLAND_DISPLAY`, the new quickshell dies on the xcb plugin, and `lock.sh` has already killed the old one by then.

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

## Terminals and tmux

Two terminals, kept deliberately in step: kitty is what `Super+Return` launches,
alacritty is still installed. A statusline that looks right in one and wrong in
the other is worse than not having it, so the font, cursor and opacity are
mirrored across both.

**The font must be named, never `monospace`.** The generic family resolves to
Noto Sans Mono on this machine, which has no Nerd Font glyphs, so tmux's
statusline separators and icons render as tofu. Both configs pin
`JetBrainsMono Nerd Font`. If you add a glyph to the statusline, check it is in
that font first — `fc-list ':charset=f0344' family` answers without installing
anything (there is no `pip`/`fontTools` on this box).

**kitty 0.49 renamed the cursor options and does not keep the old names as
aliases** — they are rejected outright with "Ignoring unknown config key", and
the rest of the file still loads, so it fails quietly:

| old | new |
|---|---|
| `cursor_beam` | `cursor_shape beam` |
| `cursor_blink` | `cursor_blink_interval 0.5` (0 **disables** blinking) |
| `cursor_thickness` | `cursor_beam_thickness` |
| `cursor_unfocused_opacity` | `cursor_shape_unfocused hollow` |

`dynamic_padding` is not a kitty option at all (that is alacritty's). The
authoritative list is `/usr/lib/kitty/kitty/options/definition.py` — the shipped
man page is only a pointer to the online docs and `kitty --help` lists no
options, so the binary's own parser is the only local oracle. Verify a change
with `kitty -e true 2>&1 | grep -i ignor`, and prove the file is actually being
read by temporarily adding a bogus key and confirming it *is* reported.

### Terminal opacity is 0.85 because it was measured

A translucent terminal sits over a *blurred* wallpaper, so the real contrast is
not the palette's foreground-vs-background pair that wallust already
guarantees — it is the foreground against the wallpaper showing through. Swept
over 51 wallpapers, each with **its own** wallust palette, taking the brightest
1% of the blurred image as the worst case (borrowing one wallpaper's palette for
all of them reports failures that are an artefact of the substitution):

| opacity | ≥4.5:1 | worst case |
|---|---|---|
| 0.60 | 21/51 | 2.06 (`linux-penguin.jpg`) |
| 0.70 | 36/51 | 3.18 |
| 0.80 | 49/51 | 4.34 |
| **0.85** | **51/51** | **5.29** |

0.85 is the lowest value that clears WCAG 4.5:1 for body text on every wallpaper
tested. Hyprland's `decoration.blur` `brightness` (0.8) is already accounted
for. Re-run the sweep in `/tmp/opencode/sweep-opacity.py` if you change it.
`dynamic_background_opacity` is **off**: kitty otherwise snaps the background to
fully opaque when the window loses focus, which on a blurred desktop is a
visible jump on every alt-tab. `background_blur` stays 0 because the compositor
already blurs the window — two blurs in series is just a softer, costlier
version of the same effect.

### tmux follows the wallpaper, in two files, because of one tmux rule

`wallust` writes two files into `~/.config/tmux/` (outside the repo, so no
`.gitignore` entry), and `.tmux.conf` sources both after its own static
Catppuccin fallback:

- `generated-colors.conf` — `colour0-15`, `default-colour`,
  `default-terminal`, `terminal-features`. **Server-start only.**
- `generated-styles.conf` — every style, in **literal `#RRGGBB`**. Re-sourced by
  `apply-theme.sh` on each wallpaper change, so the status line recolours live.

The split is not cosmetic. tmux resolves a palette *index* (`colour4`) at draw
time, but the palette itself is **frozen at server start**: `set -g colour4` is
valid in a config file and fails at runtime with "invalid option", as do
`default-colour` and the session-scoped `copy-mode-style` / `mode-keys-style`.
So a name-based style re-sourced live would faithfully repaint the *old* accent.
A hex literal is resolved when the option is set and stored as RGB, which is
what makes the live path possible. Merging the two files back together makes
every wallpaper change log a `source-file` error and exit non-zero.

Consequences worth knowing:

- **A tmux server that is already running keeps its old palette** until it is
  restarted; the styles update immediately, the `colourN` slots do not. Panes
  still look right, because kitty underneath has its own live palette. Restart
  tmux when convenient — do not `kill-server` with work in progress.
- `apply-theme.sh` probes with `tmux list-sessions`, **not `pgrep -x tmux`**: the
  server process's `comm` is the string `tmux: server`, so an exact-name pgrep
  never matches and the whole reload was a silent no-op. Ask tmux itself.
- Keep `generated-styles.conf` to options that are settable at runtime. Check
  with `tmux source-file ~/.config/tmux/generated-styles.conf; echo $?` — it
  must be `0`.
- wallust's `{{colorN}}` already carries the leading `#`. Write `fg={{color4}}`,
  not `fg=#{{color4}}`; the doubled hash is not a valid colour, tmux rejects
  that one option, and the style silently keeps its previous value.
- **tmux's `set` takes at most one name/value pair.** A second pair on the same
  line raises "too many arguments (need at most 2)" and **aborts the rest of the
  config file** — which is how an entire tmux config silently fell back to
  tmux's defaults (`status-style` reading back as `bg=green,fg=black`) with no
  error visible in the terminal. One option per line.
- **`tmux-tokyo-night` was removed from the plugin list** because it hardcodes
  its own colours, which would win over the wallpaper palette. The statusline is
  hand-rolled instead. The plugin is still on disk; remove it with
  `tpm uninstall adonespitogo/tmux-tokyo-night`.
- **tmux does not strftime-expand status lines at all** — `%H:%M` renders
  literally (verified on 3.7c). A tmux clock therefore has to be
  `#(date +...)`, which forks a shell on every `status-interval` tick. There is
  no clock in the statusline for a second reason anyway: waybar already owns one
  in `modules-center`, and two clocks on one screen is worse than the saving.

### The statusline glyphs are written as codepoints, never typed

Picking a Nerd Font icon by its name does not work, twice over.

**You cannot type these characters.** Every private-use glyph written by hand
landed on a different codepoint than intended — `U+F0120` came out as `U+F0112`,
`U+F002` as `U+F0349`, and so on, all seven. That is how copy-mode ended up
wearing a **clock face** (`U+F0150` is literally a clock), which the user
correctly read as "the icons are wrong". So:

- `wallust/templates/colors-tmux-styles.conf` stores icons as `@G_*@` tokens and
  `/tmp/opencode/expandglyphs.py` inserts them by codepoint.
- The seed in `wallust/apply-theme.sh` uses bash escapes instead, which also
  keeps that script pure ASCII.
- **Nerd Fonts v3 glyphs live in the plane-15 PUA (`U+F0000`+)**, not the BMP
  PUA (`U+E000..U+F8FF`). A verification script that only checks the BMP range
  reports "no glyphs found" in a file full of them. The set is mixed — `U+F0120`
  is plane 15, `U+F108` is BMP — so read each codepoint, don't assume.
- In bash, `$'\uXXXX'` is **BMP-only and silently truncates**: `$'\uf0120'`
  becomes `U+F012`. Use `$'\U000F0120'` (8 digits) above the BMP.

**And you cannot pick them by name either.** Rendered side by side
(`/tmp/opencode/glyphsheet.py`, which draws candidates from the TTF with PIL —
no window, no screenshot, no focus stealing):

| meant | codepoint | actually renders as |
|---|---|---|
| copy-mode | `U+F0150` | a **clock** |
| prefix | `U+F00E4` | a **beetle** |
| host | `U+F0084` | a **person** |
| bell | `U+F0761` | a **calendar** |
| host | `U+F055` | a **power button** |
| zoom | `U+F0311` | a left arrow |

Look at the glyph, then write down its codepoint. At 19px several are ambiguous
anyway — `U+F109` (laptop) reads as a plain rectangle, so the host uses
`U+F108`, which reads as a monitor with a stand.

### Why there is no powerline separator

The first version used `U+F0404` between windows and it looked like a smudge.
The Nerd Font powerline glyphs are drawn as **thin half-cell connectors meant to
abut the next cell**, but a monospace font gives every glyph the same advance
width, so they float in dead space and read as a crossed-out scribble. A plain
`│` (`U+2502`) has no such constraint and cannot overlap anything. The sliver
trick (`▌` pill edges) was tried and rejected for the same reason — it collided
with the separator.

Two more things the eye caught that reading the config did not:

- **Warning colours taken from the palette are not warning colours.** Under
  `deer-forest` the "warning" slot came out `#618435` against an accent of
  `#808832` — two olives a few percent apart, so the indicators read as noise.
  The state indicators now use **fixed** red/green. A warning that does not look
  like a warning is worse than one that does not match the wallpaper.
- **`#F` is what glued the `-` and `*` marks to the window name.** It is absent
  now; activity and bell are explicit `#{?window_activity_flag,...}`
  conditionals with their own colour and space.

### Never `pkill -f` a window from this shell

`pkill -f 'class stlvis'` matched the *calling shell*, because the pattern
appears in its own command line, and killed it mid-script — so the commands
after it silently never ran and the tmux server "did not exist". It has now
happened three times in this repo. Use the PID from `/proc` and `kill` it, or
match on something that cannot match the caller.

## Dashboard overlay (quickshell, `Super+D`)

`quickshell/shell.qml` draws a summoned overlay — calendar, MPRIS media, system
monitor, app launcher. **It is not a shell migration: waybar and swaync stay.**
`quickshell` is in `extra` (6 MiB), not the AUR, and the roadmap's old
"duplicates waybar for no gain" note was right about the bar and wrong about
the overlay — the only modules that overlap are `PanelWindow`, `SystemTray` and
`Notifications`. See RIZZ-ROADMAP.md 3.1.

**The config is the `default` one, so invoke it with no `-c`.** quickshell
registers `~/.config/quickshell/shell.qml` as `default`; `-c`/`--config` takes a
config *name* and looks for `~/.config/quickshell/<name>/shell.qml`, so
`qs -c ~/.config/quickshell` silently finds nothing. `Super+D` runs
`qs ipc call dashboard toggle` from `hyprland.lua`.

Autostart is in the `hyprland.start` block, which fires **once** — it does not
re-fire on `hyprctl reload` (verified by process start time across an
`apply-theme.sh` run), so wallpaper changes never restart quickshell.

QML traps this file already pays for, all documented inline and in
`quickshell/README.md`:

- **Never name an `id` `palette`.** Qt already owns it (`QQuickPalette`), so
  `palette.adapter` is undefined in every binding while the object itself logs as
  healthy. The id is `pal`. The symptom — object exists, properties missing —
  looks like a corrupt data file, not a name collision.
- `ExclusionMode.Ignore` is a **top-level type**, not `Quickshell.ExclusionMode`.
- `import QtQuick` is not implicit here; without it `ListView is not a type`.
- A `Row` whose child sets `anchors.right` warns "Row will not function" and
  goes inert. Wrap in an `Item`.
- Sibling order is paint order: the calendar's today-pill `Rectangle` hid its own
  day number until it got an explicit `z`.
- `Quickshell.watchFiles` defaults to **true** and reloads the whole config when
  any file in the shell directory changes — including `generated-colors.json`.
  It is set to `false` in `Component.onCompleted`; otherwise every wallpaper
  change reloads the shell and closes the overlay. This is the `hl.env` trap in
  a different costume: a file-driven feature sharing a directory with a
  file-driven reload path.
- **QtQuick.Controls is deliberately not imported.** No `TextField`, no
  `ScrollBar`. Importing it brings the Fusion style, and a launcher that
  inherits the system style would be the one surface not following the wallpaper.
  For the same reason `QT_QPA_PLATFORMTHEME=kde` does nothing for this window:
  that env var hands a palette to QWidget apps, and a QML scene gets no colours
  from `kdeglobals`. The overlay themes itself from the generated JSON.

Keyboard handling lives on the `TextInput` via `Keys.onPressed`, and
`open_()` calls `search.forceActiveFocus()`. The `Keys` handler deals with
Escape/Enter/Up/Down only and **deliberately has no `else`** — anything
unaccepted falls through to the `TextInput`, which does its own editing. An
earlier catch-all `else { search.text = event.text }` replaced the whole query
with a single character, so typing "kit" left "t"; it looked like a focus
problem rather than an overwrite. There is also no proxy `Item` with
`focus: root.open` — two items competing for focus is a silent intermittent bug.

This machine has no `wtype`/`ydotool`, but you do not need them:

    hyprctl eval "hl.dispatch(hl.dsp.send_shortcut({ mods = '', key = 'k' }))"

delivers a real key event to the **focused client**. `mods` is required and must
be a string. It does *not* fire keybinds, which is why `Super+D` and
`Super+space` are still verified only by `hyprctl binds`.

Not yet verified: the `blur-quickshell` layer rule — see the OPEN entry in
RIZZ-ROADMAP.md, where `rofi` fails the same blur test, so it is a pre-existing
session issue rather than a quickshell one.

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

## opencode (two config files, two different jobs)

`opencode/opencode.json` is the **server/project** config and `opencode/cli.json` is the
**terminal client** config. They are separate files with separate schemas and must not be
merged — `theme`, `animations`, `keybinds`, `session.*` and `mini.*` are TUI-only and are
rejected in `opencode.json`, while `plugin`, `agent`, `mcp`, `provider` and `permission` are
server-side and have no place in `cli.json`. The plugin array key is singular: `"plugin"`.

Both are linked **individually**, not as a whole `~/.config/opencode` symlink, because that
directory also holds `service.json` — the per-machine service password. It is gitignored and
stays in `~/.config/opencode`; a fresh machine gets its own when the service first starts.

`plugin: ["opencode-model-router"]` is resolved from npm, not from this repo: the package is
fetched into `~/.cache/opencode/npm/` on first run, and the router's recents/favourites live
in `~/.local/state/opencode/model.json` (machine state, deliberately not tracked). The
installed binary is `~/.opencode/bin/opencode`, which `fish/config.fish` puts on `PATH`; it
has no distro package, so a fresh machine installs it with
`curl -fsSL https://opencode.ai/install | bash` (see `install.md`).

`session.permissions: "autoaccept"` in `cli.json` means the TUI approves every permission
request without asking. It is here on purpose, but it is a trust decision, not a preference —
drop it to `"prompt"` on a machine you do not fully trust.

## install.md

Packages that must be installed manually (or via a package manager) but don't produce a dotfile tracked here. Keep it grouped by category.
