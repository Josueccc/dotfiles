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

## 🟡 Phase 2 — Accent propagation (2–3h) — highest wow/effort ratio left

The entire app UI (GTK, Qt, Firefox, Discord…) still ignores the wallpaper.

- [ ] **2.1 Run matugen** — `matugen image <wallpaper>` (in the repos) generates gtk-4/gtk-3, Kvantum, kitty, alacritty and firefox themes with proper Material You
- [ ] **2.2 Wire into apply-theme.sh** — either (a) split brain: wallust for bar/rofi/swaync, matugen for app UIs, or (b) migrate 100% to matugen
- [ ] **2.3 Qt side** — point `qt5ct/qt6ct` + `kvantum` at the generated palette
- [ ] **2.4 DECISION** — stay pure-wallust, migrate to matugen, or hybrid? The one architectural fork in the road.

## 🔵 Phase 3 — The big swing (weekend, optional)

- [ ] **3.1 Quickshell widget layer** — dashboard overlay (calendar, media player, system monitor, app launcher) summoned with one key. What the end-4/Caelestia rices run. Needs `quickshell` (AUR, heavy Qt dep tree); migrate waybar/swaync into it or keep waybar alongside.

## 🟣 Phase 4 — Apps & eye candy (1–2h each)

- [ ] **4.1 Live video wallpapers** — `mpvpaper` replaces the `swaybg` waypaper backend
- [x] **4.2 awww transitions** — done. `backend = awww` in `waypaper/config.ini` (waypaper 2.9 has a native awww backend: it starts the daemon, kills the old painter, reads the `swww_transition_*` keys). `wave` @30° / 1.2s / 60fps, verified animating via mid-transition screenshots. Picker now goes through `waypaper --wallpaper` so `post_command` → `apply-theme.sh` keeps firing; the awww/swaybg fallbacks call it themselves. Also fixed `folder` (was `~/Downloads`, empty → now `~/Pictures/wallpapers`)
- [ ] **4.3 Terminal flex** — transparency tuned to the blur, nicer cursor, tmux statusline recolored to the live palette
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
