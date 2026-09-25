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
- [~] **1.2 hyprlock** — polished in code: lock glyph, `hide_cursor`, custom fade curve, hint line, brighter/sharper screenshot bg. **needs a live look** (`Super+Ctrl+L`) — hyprlock has no config-verify mode, so eyeball it
- [x] **1.3 hyprsunset night light** — done, but *not* with a timer: hyprsunset 0.4 has native time-based profiles (`hyprland/hyprsunset.conf`, 00:00 identity / 18:45 5000K / 22:30 3500K), autostarted from `hyprland.lua`. `Super+Shift+M` = manual override via `hyprland/scripts/nightlight.sh`
- [~] **1.4 cava in the waybar** — wired: `custom/cava` module + `waybar/scripts/cava.sh` + `cava/config` (raw/ascii mode, digits→block glyphs, colored from the wallpaper palette in CSS). **needs `sudo pacman -S cava`** — not installed yet, so it's hidden by `exec-if`
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
- [ ] **4.2 awww transitions** — awww is installed, **swww is not** (removed since Phase 0), and waypaper's `backend = swaybg` still points at the pre-swww daemon. So today the picker silently falls through to `waypaper --wallpaper`: no transition, and theming only works because waypaper fires `post_command`. When this gets done, the fast path must call `wallust/apply-theme.sh "$chosen"` itself, otherwise picking a wallpaper stops re-theming the desktop
- [ ] **4.3 Terminal flex** — transparency tuned to the blur, nicer cursor, tmux statusline recolored to the live palette
- [ ] **4.4 hypridle chain** — DPMS off → screen off → lock, fading into the blurred lock screen

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
