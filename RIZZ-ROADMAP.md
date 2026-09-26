# 🗺️ Rizz Roadmap

Living plan for the Hyprland setup in this repo. Ordered by wow-per-effort.
Check items off as you land them.

---

## ✅ Phase 0 — Shipped

The foundation. Full wallpaper-driven theming pipeline, verified live:

- **wallust** extracts a 16-color palette from the wallpaper (`palette = "dark16"`)
- `wallust/apply-theme.sh` re-themes **hyprland borders · waybar · rofi · swaync · kitty · alacritty** and reloads each app
- wired into waypaper's `post_command` → changing the wallpaper repaints the whole desktop
- **hyprland**: blur (2-pass, layer rules for bar/rofi/swaync/swayosd), `wind`/`winIn`/`winOut` curves, popin windows, rotating gradient border (`borderangle` loop), rounding 12, softer shadows
- **waybar**: island pills, elongated gradient active workspace
- **rofi / swaync**: restyled, translucent so the blur shows through
- **hyprlock**: 110px clock with drop shadow, pill input field
- static Catppuccin fallbacks everywhere (`apply-theme.sh --seed`), generated files gitignored
- repo plumbing: `install.sh` symlinks wallust + seeds, `packages.sh` gained wallust, `CLAUDE.md` documents the mechanism

---

## 🟢 Phase 1 — Quick wins (1–2h total, zero new architecture)

- [x] **1.1 Commit Phase 0** — done (rizz work in one commit, unrelated pending edits in another)
- [x] **1.2 hyprlock** — verified live: padlock glyph, 110px clock, pill input, hint line, blurred desktop bg, `hide_cursor`. Glyph note: the lock is U+F0233 and the user icon is U+F0004 — the old user glyph was U+F033E, which is a padlock-with-dot, so the screen had two locks on it
- [x] **1.3 hyprsunset night light** — done, but *not* with a timer: hyprsunset 0.4 has native time-based profiles (`hyprland/hyprsunset.conf`, 00:00 identity / 18:45 5000K / 22:30 3500K), autostarted from `hyprland.lua`. `Super+Shift+M` = manual override via `hyprland/scripts/nightlight.sh`
- [x] **1.4 cava in the waybar** — live and reacting to audio. `custom/cava` module + `waybar/scripts/cava.sh` + `cava/config` (raw/ascii mode, digits→block glyphs, colored from the wallpaper palette in CSS). Two bugs found by testing rather than by looking: `bar_delimiter = 0` does not mean "no separator", it emits a NUL byte, and `noise_reduction` needs to be low (60) or the bars barely move
- [x] **1.5 Window rule polish** — done: `popup()` helper in `hyprland.lua` floats/sizes/centers pavucontrol, nm-connection-editor, blueman, GTK/portal file choosers, thunar archive dialogs, satty/swappy; polkit popups are pinned too

## ✅ Phase 2 — Accent propagation — landed (GTK3 + Qt6), GTK4 abandoned

The app UI ignored the wallpaper. Both toolkits are now handled, by two different fixes.

**Qt6 (Dolphin and every other Qt6/KF6 app) — fixed, and it was not matugen.**
`QT_QPA_PLATFORMTHEME` is now `kde` (`KDEPlasmaPlatformTheme6.so`, from `plasma-integration`),
which reads `kde/kdeglobals` and hands Qt the `[Colors:*]` palette. Dolphin samples `#1e1e2e`,
the Catppuccin base. Three wrong turns along the way, all now recorded in CLAUDE.md:

- `hyprqt6engine` really is broken (`libhyprutils.so.12` vs the system's `.13`), but that was
  only *half* the story.
- `qt6ct` was the previous fix and it is **wrong for KF6 apps**. Its plugin loads fine and
  themes plain Qt6 apps correctly (pavucontrol is pixel-identical under `qt6ct` and `kde`),
  but Dolphin stays light: `#eff0f1` under qt6ct vs `#1e1e2e` under `kde`. The old
  verification used pavucontrol, i.e. the one app class qt6ct handles correctly, so the KF6
  breakage was invisible. **Test with Dolphin, not pavucontrol.**
- The live session was also masking it: Hyprland started 13:35:05, `hyprland.lua` was edited
  17:08:07, so `hl.env` had never applied. This build has no `hyprctl setenv` ("unknown
  request"), so a correct fix stays invisible until you relog. That is how the qt6ct "fix"
  sat in the repo for hours looking broken.

Proved the `kde` theme really reads our config by setting `BackgroundNormal=255,0,255`:
Dolphin turned magenta. Also fixed a live `GKT_THEME` typo (should have been `GTK_THEME`);
it was exported all along and harmless only because nothing reads that name.

**GTK3 (thunar, blueman, gnome-disks) — matugen, wired into the wallpaper pipeline.**
`apply-theme.sh` now runs matugen next to wallust, writing `~/.config/gtk-3.0/colors.css`
from `matugen/templates/breeze.css` (84/84 Breeze variables; matugen's stock template emits
adwaita names, which Breeze ignores). Verified end-to-end: `deer-forest.jpg` → `#141318`,
`serial_experiments_lain.png` → `#111318`, same window.

**Corrected conclusion on payoff.** The old "the visual payoff is small" note was measured
on *surfaces* (`#242424` → `#141318`, genuinely near-invisible). The payoff is in the
**accents**: stock Breeze hardcodes `theme_selected_bg_color_breeze #315bef`, a bright blue
unrelated to any wallpaper and the loudest colour in a file manager. matugen derives it
(`#473f77` under deer-forest). Judged with a purpose-built GTK3 preview window
(`/tmp/opencode/gtk-preview.py`) that shows selection/link/checkbox/button states, because
two idle file managers are nearly indistinguishable.

- [x] **2.1 Run matugen** — done
- [x] **2.2 Choose the split** — wallust for the shell, matugen for GTK3, `kde` platform theme for Qt6
- [x] **2.3 Qt side** — done via `QT_QPA_PLATFORMTHEME=kde`, **not** qt6ct
- [x] **2.4 DECISION** — hybrid, but a narrower one than planned. Qt6 came from `kdeglobals`,
      so it cost one env var and no new dependency. matugen earns its place on GTK3 accents only.
- [ ] **2.5 GTK4** — **abandoned, deliberately.** `gtk-4.0/colors.css` was a dead file (the
      `gtk.css` symlink points into the catppuccin theme, which has no `@import`). It cannot be
      revived from the user dir: GTK4 honours `@import 'x'` but silently ignores `@import url('x')`,
      and `gtk-dark.css` loads at higher priority than `gtk.css`, so the catppuccin palette always
      wins. A forced-magenta probe proved the override never reaches the widget. Breeze does not
      define `window_bg_color` but every catppuccin theme does, so there is nothing to override.
      Blast radius is one app (`gnome-calendar`; blueman-manager is a Python/GTK3 script and
      gnome-disks is GTK3). Left exactly as found. The promising route is a custom *theme* dir
      wrapping catppuccin, not another user `gtk.css`.

- [x] **2.6 Browsers/Electron** — **Firefox done, Brave done (reduced), Discord declined.**
      **Firefox 156** follows the wallpaper via `wallust/templates/colors-firefox.css` →
      `firefox/{userChrome,userContent,fallback,generated-colors}.css`, linked into
      `<profile>/chrome/` by `firefox/link-profile.sh`. Both browser chrome *and*
      the about: pages are themed. The `chrome/` subdirectory (not the profile root)
      is the entire mechanism, and `--lwt-*` is dead in 156 — see CLAUDE.md for the
      four silent-failure traps and the token names. Verified by two-colour probe
      (213,082 cyan / 0 magenta) and by pixel-sampling the live `about:preferences`
      against the palette exactly (`#171519` canvas, `#424045` cards, `#FEF7EF` text).
      Accent is `color7`, chosen by sweeping candidate mappings over 30 wallpapers:
      `color4` fails as both link text (3.43 vs 4.5 needed) and focus ring (1.94 vs
      3.0 needed); `color7` passes 30/30.
      **Brave is a seed colour, not a palette.** `brave --version` reads `154.1.96.59`
      — that is *Chromium* 154, not Brave 1.96 — and M154 deleted the multi-colour
      native theme (`frame_color` and `chrome.theme` both absent from the binary) and
      the WebExtension theme API with it. One ARGB seed + a variant is all that
      remains. Smaller win, but the payoff was always the accent.
      **Discord declined:** no theming surface exists; the only route patches
      `app.asar` and re-breaks on every update.
      Both browsers apply on **next launch** — there is no live reload, unlike waybar.


## 🔵 Phase 3 — The big swing (weekend, optional)

- [ ] **3.1 Quickshell widget layer** — dashboard overlay (calendar, media player, system monitor, app launcher) summoned with one key. What the end-4/Caelestia rices run. Needs `quickshell` (AUR, heavy Qt dep tree); migrate waybar/swaync into it or keep waybar alongside.

## 🟣 Phase 4 — Apps & eye candy (1–2h each)

- [ ] **4.1 Live video wallpapers** — `mpvpaper` replaces the `swaybg` waypaper backend
- [x] **4.2 awww transitions** — done. `backend = awww` in `waypaper/config.ini` (waypaper 2.9 has a native awww backend: it starts the daemon, kills the old painter, reads the `swww_transition_*` keys). `wave` @30° / 1.2s / 60fps, verified animating via mid-transition screenshots. Picker now goes through `waypaper --wallpaper` so `post_command` → `apply-theme.sh` keeps firing; the awww/swaybg fallbacks call it themselves. Also fixed `folder` (was `~/Downloads`, empty → now `~/Pictures/wallpapers`)
- [x] **4.3 Terminal flex** — done, and the transparency number is measured, not taste.
      Opacity is **0.85** in both kitty and alacritty: a translucent terminal sits over a *blurred*
      wallpaper, so the contrast that matters is not the palette pair wallust already guarantees but
      the foreground against the wallpaper showing through. Swept over 51 wallpapers, each with its
      own wallust palette, worst case = brightest 1% of the blurred image: 0.60 → 21/51 wallpapers
      clear 4.5:1, 0.80 → 49/51, **0.85 → 51/51** (worst 5.29). First attempt used one wallpaper's
      palette for all of them and reported failures that were an artefact of the substitution.
      `dynamic_background_opacity` off (otherwise kitty snaps opaque on focus loss, a visible jump
      over a blur); `background_blur` stays 0 because the compositor already blurs.
      **tmux follows the wallpaper too**, in two generated files split by the one rule that decides
      it: tmux freezes its palette at server start (`set -g colour4` is valid in a config file and
      fails at runtime with "invalid option"), so the styles are written as literal hex and
      re-sourced live, while `colourN` stays startup-only. Hand-rolled powerline statusline
      replaced `tmux-tokyo-night`, which hardcoded colours that would win over the wallpaper. No
      clock: tmux does not strftime-expand status lines at all (`%H:%M` renders literally), the
      alternative forks a shell per tick, and waybar already has one in `modules-center`.
      Verified live: `4:limpio*` filled accent pill, `󰐄` separators, `cachyos-x8664` right-aligned,
      beam cursor, no tofu — which required pinning `JetBrainsMono Nerd Font` in *both* terminals,
      since alacritty's `family = "monospace"` resolves to Noto Sans Mono and has no Nerd glyphs.
      Along the way, kitty 0.49 had renamed every cursor option (`cursor_beam` → `cursor_shape`,
      `cursor_blink` → `cursor_blink_interval`, …) and rejects the old names outright
- [~] **4.4 hypridle chain** — the *timing* is fixed (5 min dim → 15 min lock → 25 min dpms off → 45 min suspend, was locking at 6). The **fade** is still missing: hypridle 0.1.8 is the newest on Arch and rejects the `dpms` listener key, so the "fade into the blurred lock screen" wants a brightness ramp script in `on-timeout` instead — or a newer hypridle

## ⚫ Phase 5 — Bleed edge / someday

- [ ] **5.1 Swap waypaper → mpvpaper** as wallpaper manager (video + static); bigger rewrite of the picker's rofi grid
- [ ] **5.2 niri scroll-driven WM** — in the repos, ~20min test in a TTY; smoothest tiling there is
- [ ] **5.3 Audio vibes** — always-on cava, album art in the bar, now-playing on the lock screen
- [ ] **5.4 Display manager theme** — SDDM/plymouth so login matches the rice

---

## 🚫 Deliberately deferred

| Idea | Why not |
|---|---|
| Quickshell/AGS full shell | Duplicates waybar for no gain |
| GTK4 libadwaita rewrite | Breaks apps |
| Custom C++/shader window effects | Perf on the GTX 1650, high maintenance |
| Rivals-style anything | Not a real thing, ignore it |

## 📌 Session notes (learned the hard way)

- **`swww` is dead** — it was archived upstream and isn't installed; `awww` is the successor and is what waypaper drives now
- **`hypridle` timed the lock at 6 min** (`timeout = 360`), which fired during a long build and hid the desktop. Now 5 min dim → 15 min lock → 25 min dpms off → 45 min suspend. Suspend moved to last on purpose: at the old 30 min it could suspend mid-build while the screen was still lit
- **hypridle 0.1.8 is the current Arch version** and it does *not* support the newer `dpms` / `check_interval` listener keys (verified by feeding it deliberately bogus keys and watching which ones it rejects). The fade/DPMS chain from 4.4 needs a newer hypridle, so for now it's a plain `hyprctl dispatch dpms off` on a timer
- **`waypaper/config.ini` is gitignored** — waypaper rewrites the whole file on every pick. Settings moved to `waypaper/config.ini.template`, seeded by install.sh; volatile keys go to waypaper's own state file via `use_xdg_state = True`
- **waybar is restarted** by `wallust/apply-theme.sh` on every wallpaper change, so a cava launched by waybar dies with it — the wrapper script reaps stale ones on startup
- **waybar's cava module is not available on Arch** (upstream builds with `-Dcava=disabled`), hence `custom/cava`
- **cava's normal output can't be piped** — ANSI escapes and a stdout window-size probe. Raw/ascii mode is the only pipe-safe path
- **`bar_delimiter = 0` in cava means NUL, not "nothing"** — it looks like the obvious way to remove the separator and quietly corrupts the output instead. Use a printable char
- **Playing a test tone to check cava needs `paplay`**, not `pactl play-file` (that subcommand doesn't exist) — worth remembering, since "are the bars moving?" is otherwise hard to answer
- Verify a wallpaper change actually animated by diffing mid-transition screenshots, not by trusting exit codes — the client returns immediately and the daemon animates
- **`hyprqt6engine` is installed but broken** — it links `libhyprutils.so.12` while the system has 0.14.2 (`.13`), so the platformtheme plugin never loads and Qt6 apps silently fall back to a *light* palette. `hyprqt6engine.conf` is dead config: editing it changes nothing. **Superseded**: the working fix is `QT_QPA_PLATFORMTHEME=kde`, not qt6ct — see the qt6ct trap below
- **The Qt6 fix was verified against the wrong app.** `qt6ct` themes plain Qt6 apps fine (pavucontrol is pixel-identical under `qt6ct` and `kde`) but KF6 apps override its palette and stay light. Dolphin: `#eff0f1` under qt6ct, `#1e1e2e` under `kde`. Checking that the plugin *loads* is not the same as checking a KF6 app is dark
- **`hl.env` only applies at startup** — Hyprland parsed its config at 13:35:05, `hyprland.lua` was edited at 17:08:07, so the change was inert all session. `hyprctl setenv` returns "unknown request" on 0.56.2, so there is no live patch: **a correct env fix needs a relog before you can see any effect.** The most expensive trap in this repo
- **`pkill -f <script>` matches the calling shell** when the pattern appears anywhere in its command line — it killed my own shell twice, and the empty output looked like a hang. Track PIDs in a file instead
- **`pgrep -x tmux` never matches anything** — the server process's `comm` is the string `tmux: server`, so an exact-name pgrep exits 1 forever and the wallpaper-driven tmux reload was a silent no-op. Ask tmux (`tmux list-sessions`) instead of guessing process names
- **One config error can abort the *rest* of the file and look like nothing happened** — tmux's `set` takes one name/value pair, so a second pair on the line raised "too many arguments" and every option after it was silently dropped, leaving `status-style` at tmux's default `bg=green,fg=black`. Verify a config by reading an option back, not by "it didn't complain"
- **tmux resolves a palette index at draw time but freezes the palette at server start** — so a wallpaper theme can live-update its *styles* (hex literals) and never its `colourN` slots. Two things that read as bugs: an already-running tmux keeps the old palette until restart, and re-sourcing a name-based style faithfully repaints the *old* accent
- **A terminal's own parser is the only local oracle for its option names** — kitty's man page is a pointer to the web, `--help` lists no options and `--debug-config` prints nothing; `definition.py` has the table. Prove the file is being read by adding a bogus key and checking it *is* reported, because a clean run proves nothing on its own
- **Borrowing one wallpaper's palette to reason about another invents failures** — the palette comes from the image, so the substitution decides the verdict, not the wallpaper. Run wallust per image in a sandbox (`wallust -d <dir>`) for each one's real palette
- **Measure the surface you actually composite over, not the one you configured** — terminal legibility is foreground vs *blurred wallpaper*, which no palette pair can guarantee. Worst case is the brightest 1% of the blurred image, and Hyprland's `decoration.blur` `brightness` scales the backdrop down, so ignoring it makes the problem look worse than it is
- **`brave --version` lies about the major version** — it prints `154.1.96.59`, and `1.96` is the *Chromium* milestone, not Brave's. It is Brave 154 / Chromium 154, which deleted the multi-colour native theme outright. Read the milestone as a browser version and you hunt for features that no longer exist
- **`/usr/bin/brave` is a bash wrapper, not the binary** — the ELF is `/opt/brave-bin/brave`. Probing the wrapper with `strings` returns 0 hits for *everything*, which looks like confirmation of whatever you hoped for
- **Firefox loads `userChrome.css` from `<profile>/chrome/`, not the profile root** — and libpref's own comment in `all.js` ("checking the user profile directory") is wrong too. Silent, no warning. Settle it with a two-colour probe (one colour in the root, another in `chrome/`, count the pixels), not by reading a guide
- **Firefox's `--lwt-*` tokens are unreachable without a WebExtension theme** — the skin only consumes them inside `:root[lwtheme]`, set only when a theme extension is installed. Setting `--lwt-accent-color` by hand is a no-op, not an override
- **Grepping `omni.ja` for `--tab-*` finds pdf.js first** — `--tab-bg` and `--tab-text-color` are real but belong to the bundled PDF viewer's `viewer.css`, not browser chrome. They look like a perfect answer and are not one
- **Firefox splits its jars** — browser chrome skin is in `browser/omni.ja`, platform skin in `omni.ja`. Tokens that look missing are usually in the other jar; I "proved" five tokens nonexistent by reading only the wrong one
- **The obvious accent is the wrong accent** — `color4` fails as link text (3.43) and as a focus ring (1.94); `color6` passes 23/30 wallpapers; `color7` passes 30/30. Measure the pairings, don't eyeball the palette
- **GTK4 silently ignores `@import url('x.css')`** but honours `@import 'x.css'`. Both parse without error, so the failure is invisible; pixel-sample the app to confirm
- **`gtk-dark.css` outranks `gtk.css`** in GTK4, so a palette in the user `gtk.css` cannot override a theme defining the same names — which every catppuccin theme does for `window_bg_color`
- **Confirm a palette override with a probe nobody can misread**: set the colour to magenta and check the app turns magenta. A plausible result is not proof the override landed
- **qt6ct's `dusk.conf` is a light scheme** — named like a dark one. Pointing `color_scheme_path` at it gives light-grey windows
- **Single-instance Qt apps will lie to you** — a stale `breeze-settings6` kept getting re-raised, so three consecutive "the fix didn't work" results were screenshots of the *old* process. Check `/proc/<pid>/environ` and confirm the pids are really gone before trusting a before/after

## ⚡ Perf notes (GTX 1650 + Vega iGPU)

- Blur is the heaviest effect — if the 1650 ever renders the compositor, drop `size` to 4 / `passes` to 1 in `hyprland.lua`
- Force GTK/Qt apps onto the **Vega iGPU** via an `env` block if you see jank; leave browsers/Steam on the 1650
- cava in the bar is cheap (ASCII text), fine

---

## How to use this file

- `[x]` done · `[~]` landed in the repo but still needs a live look on screen · `[ ]` not started
- Tick boxes as you land items
- New ideas go to the bottom of the matching phase
- Delete phases once fully done (Phase 0 kept as history)
