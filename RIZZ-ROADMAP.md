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


## 🔵 Phase 3 — Quickshell dashboard overlay (landed, overlay-only)

- [x] **3.1 Quickshell widget layer** — done, and deliberately **not** a shell
      migration. `quickshell/shell.qml`: calendar, MPRIS media, system monitor
      and app launcher in one `Super+D` overlay. **waybar and swaync are
      untouched** — see the correction below.

  **Two premises in the old entry were both wrong.**

  *"Needs `quickshell` (AUR, heavy Qt dep tree)"* — it is in **`extra`**:
  `0.3.1-1.1`, 1.66 MiB download / 6.08 MiB installed. It was added to
  `PACMAN_DESKTOP` in `packages.sh`, not the AUR list. The cost of this item was
  never the dependency.

  *"Duplicates waybar for no gain"* (the deferral table) — wrong about the
  overlay, right about the migration. Reading 0.3.1's actual type index rather
  than going from memory, the overlap is exactly three modules and none of them
  are the dashboard: `PanelWindow` (topbar), `Services.SystemTray`,
  `Services.Notifications`. Everything the overlay needs is something waybar
  cannot do at all — `DesktopEntries` (launcher), `Services.Mpris` (media +
  art), `Hyprland` (native IPC instead of parsing `hyprctl` text),
  `Services.UPower`, `Services.Polkit`, `Wayland.WlSessionLock`. So the
  deferral entry is now narrowed to what it was actually protecting against:
  **migrating the bar.** That is still deferred, deliberately.

  **It follows the wallpaper better than anything else in the pipeline.** It is
  the only consumer that needs no restart: `shell.qml` reads
  `generated-colors.json` through a `FileView` + `JsonAdapter` with
  `watchChanges`, so `apply-theme.sh` has no reload line for it at all. Proven
  by re-theming a running instance to a greyscale wallpaper and pixel-sampling
  every accent to `R=G=B`.

  Verified: IPC toggle, month grid, launcher filter/icons/scroll, MPRIS against
  VLC (including the `|| "Unknown Title"` fallbacks and the `canXyz` capability
  gates), CPU/RAM/load, and the **whole keyboard** — type-to-filter, Backspace,
  Up/Down, Escape, and Enter actually launching an app, all driven with real key
  events (see the `send_shortcut` note below). Not verified: the
  `blur-quickshell` layer rule, and `Super+D` itself, which needs a real
  keypress.

- [ ] **3.2 Absorb what quickshell does natively better** *(scope B, not
      started)* — `Services.Polkit` as a real agent, which would delete the
      pinned-polkit popup rules from 1.5, and `Services.UPower`, which would
      replace `waybar/scripts/power-profile.sh`'s rofi picker. Both replace
      shell-script hacks with real APIs. Low risk, no waybar migration.
- [ ] **3.3 Lock-screen now-playing** *(scope B+, not started)* —
      `Wayland.WlSessionLock` would deliver the missing half of 5.3. Note this
      means replacing hyprlock, which Phase 1.2 tuned by hand.
- [ ] **3.4 Waybar migration** — still deferred. The bar is already verified
      pixel-correct on a 0.3.x API that is versioned per-minor, so the
      regression surface is large and the payoff is zero.

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
      Verified live: filled accent pill, `cachyos-x8664` right-aligned, beam cursor, no tofu —
      which required pinning `JetBrainsMono Nerd Font` in *both* terminals, since alacritty's
      `family = "monospace"` resolves to Noto Sans Mono and has no Nerd glyphs.
      Along the way, kitty 0.49 had also renamed every cursor option (`cursor_beam` → `cursor_shape`,
      `cursor_blink` → `cursor_blink_interval`, …) and rejects the old names outright

      **Second pass, after the user reported the icons were unreadable and overlapping.** The
      powerline statusline was wrong in three ways, none visible by reading the config back:
      - **A powerline separator cannot work in a monospace font.** `U+F0404` is a thin half-cell
        connector meant to abut the next cell; every glyph gets the same advance width, so it
        floats in dead space as a crossed-out smudge. Replaced with a plain `│`. The `▌` sliver
        pill edges were tried and rejected for the same reason — they collided with the separator.
      - **The glyphs were the wrong glyphs.** `U+F0150` ("copy-mode") is literally a clock face,
        which is why an unexplained clock kept appearing on the bar; `U+F00E4` is a beetle,
        `U+F0761` a calendar, `U+F055` a power button. All seven icons now come from a rendered
        comparison sheet (`/tmp/opencode/glyphsheet.py`) instead of from codepoint names.
      - **Warning colours drawn from the palette were invisible.** `#618435` against an accent of
        `#808832` is two olives a few percent apart, so the indicators read as noise. State
        indicators now use fixed red/green, deliberately not from the wallpaper.
      Also: `#F` was what glued the `-` and `*` marks to the window name — replaced with explicit
      conditionals that get their own colour and space. Net layout:
      `>_ session │ 1:fish │ [2:nvim] │ 3:logs …` with a plain filled pill for the active window.
      Re-verified on screen at real terminal size, not only in a mock-up.
- [x] **4.4 hypridle chain** — the timing was already right (5 min fade → 15 min lock → 25 min dpms off → 45 min suspend, was locking at 6). The **fade** landed as `hyprland/scripts/dim-ramp.sh`, and chasing it turned up two defects that had been hiding in plain sight:

  - **`brightnessctl set 10` is a raw sysfs value, not 10%.** The panel maxes at 65535, so the dim step was asking for 0.015% — a black screen at five minutes — directly under a comment that said it was dimming the panel. The script takes a real percentage, converts it against the device max (10% → 6553), and interpolates a **smoothstep**, because a linear fade spends most of its time in the invisible tail and looks like a stall. The lock at 15 min then lands on an already-faded panel, so no second ramp: adding one would widen the window in which someone who came back still gets locked.
  - **The 25-minute screen blank had never run.** This Hyprland's `hyprctl` is the Lua build, so `hyprctl dispatch dpms off` is rewritten to `hl.dispatch(dpms off)` and dies on a Lua parse error — off a timer, into a log nobody reads. The working form is `hyprctl eval "hl.dispatch(hl.dsp.dpms('off'))"`. The same bug was live in `hyprland.lua` twice: `Super+space` (switchxkblayout) and the `hyprctl dispatch exit` half of `Super+M`, the latter masked because `hyprshutdown` is tried first and exists.

  - **The obvious repair for `Super+space` is unverifiable, so it was replaced instead.** There *is* a Lua `switchxkblayout` dispatcher, but no constructor fails — a dispatcher named `totally_bogus_name` returns `ok` exactly like a real one — so four plausible call shapes all reported success while the keymap never moved. Rather than ship a call that only *looks* right, `hyprland/scripts/toggle-kb-layout.sh` rewrites the layout list with `hl.config({input={…}})`, which is observable: `English (US)` ↔ `Spanish (Latin American)`, verified both ways. The catch is that `input:kb_layout` and `input:kb_variant` are **parallel lists** — rotating one alone puts the `intl` variant on the Spanish layout, which types `ñ` as `~`. The layout is now **standard US** rather than US-international: `"intl,"` makes the accented characters dead keys, which is easy to forget you are holding one.

  - **The toggle is a read-modify-write, and that made rapid presses vanish.** Two presses arriving together could both read the same list and both write the same answer, so one was silently lost — reported as "I have to wait a moment before it cycles". It reproduced roughly one press in three, which is the worst shape of bug: intermittent, so it looks like a flaky key rather than a race, and the first two attempts to reproduce it failed. Fixed with `flock` around the whole read-compute-write; verified with 2 and 3 *simultaneous* presses over repeated rounds, not with sequential ones.

  Verified on the real panel, not by reading the file back: hypridle firing the dim step lands on exactly 6553; `wake` restores 22938; a `wake` mid-fade kills the ramp (a bash `trap` that only cleans up would keep dimming, since bash continues after a trapped signal) and the brightness stays put 1.5 s later; a second `dim` while one is in flight refuses to start, so the saved level is never an already-dimmed value. dpms was proved by `hyprctl monitors | grep dpmsStatus` going 1 → 0 → 1 through the exact string in the config, run via `sh -c` the way hypridle runs it.

  Not verified, and honestly so: pressing `Super+space` itself. The bind is registered (`hyprctl binds` shows `space` → a Lua dispatcher) and the script it calls is proven, but firing a bind needs a real keypress — `hl.dsp.send_shortcut` did not trigger it in any of the shapes tried, and "nothing happened" is indistinguishable from "wrong argument shape" when nothing validates. The `hl.dispatch(hl.dsp.exit())` logout fallback is unverified for the same reason and one step worse: testing it ends the session.

  Still open: whether 10% is the right floor for reading a password in daylight. It is the number the config always intended; it has just never actually happened before.

## ⚫ Phase 5 — Bleed edge / someday

- [ ] **5.1 Swap waypaper → mpvpaper** as wallpaper manager (video + static); bigger rewrite of the picker's rofi grid
- [ ] **5.2 niri scroll-driven WM** — in the repos, ~20min test in a TTY; smoothest tiling there is
- [ ] **5.3 Audio vibes** — always-on cava, album art in the bar, now-playing on the lock screen. The lock-screen half overlaps 3.3, which would do it in quickshell instead of hyprlock
- [ ] **5.4 Display manager theme** — SDDM/plymouth so login matches the rice

---

## 🚫 Deliberately deferred

| Idea | Why not |
|---|---|
| Quickshell/AGS full shell | Superseded — the *overlay* shipped in 3.1, and only the bar migration is still deferred (3.4) |
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
- **A percentage that is not a percentage** — `brightnessctl set 10` is a raw sysfs value; on a 65535-max panel it is 0.015%, i.e. black. The command takes `50%` if you mean percent, and a comment saying "dim" is not evidence that it dims
- **A one-shot `set` is not a fade**, and a linear one looks like a stall: interpolate with a smoothstep so the ends are gentle, or most of the ramp happens where nobody can see it
- **A bash `trap` on TERM runs the handler and keeps going** — a cleanup-only trap lets a killed ramp keep writing brightness after `wake` restored it. The handler has to `exit`
- **This machine's `hyprctl` is the Lua build, and it fails as a parse error, not a usage error** — `hyprctl dispatch dpms off` becomes `hl.dispatch(dpms off)`. A timer-driven command that dies this way logs nothing where anyone looks, so a step can be broken for months and still look configured. Use `hyprctl eval "hl.dsp.dpms('off')"`
- **`hypridle -v` does not exit** — it prints the rules and then keeps running, so a bare `hypridle -c … -v` hangs the shell. `timeout 3` it; `| head` only works because `head` closes the pipe
- **`ps -C <script>` and `pgrep -x <script>` do not find your own scripts** — the kernel `comm` is `bash`, not the script name. And `pgrep -f <pattern>` finds *your own shell* whenever the pattern is in the command line you are running, which is why counting processes by pattern is not a way to count ramps
- **hypridle reads its config once and has no reload** — a fixed config does nothing until the daemon is restarted, which makes a correct fix look broken (the same shape as the `hl.env` trap above)
- **A Lua dispatcher you construct is not a Lua dispatcher you ran** — `hl.dsp.dpms('off')` returns a Dispatcher and does nothing; `hl.dispatch(...)` is what executes it. Shipping the bare form looked correct and blanked nothing
- **`ok` from a control API is not a result** — a dispatcher named `totally_bogus_name` returns `ok`, a malformed one returns `ok`, and a constructed-but-unrun one returns `ok`. Four wrong shapes in a row all "succeeded". When nothing validates, the only trustworthy oracle is observable state: `dpmsStatus`, `active keymap`, `hyprctl binds`, a screenshot
- **Two config lists that look like one** — `input:kb_layout` and `input:kb_variant` are positional and parallel. Reordering one silently applies the other's entries to the wrong layouts, which types `ñ` as `~` and never complains
- **A read-modify-write behind a keypress loses presses, and an intermittent race reads as a flaky key** — two toggles that both read the old value write the same answer. It reproduced about one time in three, so the first two attempts to catch it *didn't*, and "press it again slower" is the only symptom. Serialise it (`flock`) and verify with *simultaneous* invocations over several rounds; a sequential test cannot see the bug
- **"US international" is a trap in a Latin-American keyboard layout** — `kb_variant = "intl,"` makes ñ/´ dead keys, so typing a Spanish word emits modifier-then-letter and looks like a broken keyboard. Plain `us` is the sane default; the variant only earns its place if you deliberately want compose-style accents
- **A rotation that appends a separator accumulates whitespace** — `" latam, us"` → `" us,  latam"` → a list that is mostly spaces after a week of keypresses. Normalise on the way out, and unit-test the transform against 1, 2 and 3 entries
- **A QML `id` can silently lose to a Qt-internal type** — naming the palette `FileView` `id: palette` makes `palette.adapter` undefined in every binding (1322 `TypeError`s) while `Component.onCompleted` logs the adapter as alive and healthy. Binding it printed `QQuickPalette(0x…)`. The tell is that the object exists but its *properties* don't, which looks like a corrupt data file rather than a name collision
- **A successful IPC call is not a visible window** — the overlay held its state in `property bool open` while the window had a literal `visible: false`. `qs ipc call dashboard open` returned success, the function ran, and nothing appeared. Nothing connected the state to the surface
- **Sibling order is paint order, and a `Rectangle` sibling will hide a `Text`** — the calendar's "today" pill was declared after the day number, so the current date rendered invisible. Fixed with an explicit `z`
- **A `Row` stops laying out if a child also sets anchors** — `anchors.right` inside a `Row` warns "Row will not function" and the row goes inert. Wrap in an `Item`
- **`Quickshell.watchFiles` defaults to true and reloads the entire config when any file in the shell dir changes** — so a `generated-colors.json` in that directory made every wallpaper change reload the shell. It is the same trap as `hl.env`, wearing a different hat: a file-driven feature and a file-driven reload path in the same directory
- **A CPU percentage from `/proc/stat` needs two samples** — it is cumulative jiffies, so the first tick can only set a baseline. The first two seconds read `0%`, which looks like a broken monitor
- **`hyprctl eval "hl.dispatch(hl.dsp.send_shortcut({ mods = '', key = 'k' }))"` injects real key events into the focused client** — this machine has no `wtype`, `ydotool` or `dotool`, and the 4.4 notes record `hl.dsp.send_shortcut` as "did not trigger binds in any of the shapes tried". Both are true and they describe different things: it does **not** go through the bind dispatcher, but it **does** deliver to the focused window. So any focused client can be keyboard-tested with nothing installed. `mods` is required and must be a string (`''` for none) — omitting it errors, and so does `mods = {}`. This is how 3.1's entire keyboard got verified. It also means a *keybind* still cannot be tested this way, which is why `Super+space` and `Super+D` remain stuck on "the bind is registered" as their only evidence
- **A catch-all `else` in a QML `Keys` handler silently eats text input** — routing unhandled keys with `search.text = event.text` replaces the query with one character, so typing "kit" leaves "t". It reproduces on the first keypress but reads like the field losing focus rather than a string being overwritten, which is how it got shipped. Handle only the keys you want and leave the rest **unaccepted**, so the focused item does its own editing
- **Two items both claiming focus is a silent, intermittent bug** — a proxy `Item` carrying `focus: root.open` next to a `TextInput` that also wants focus. Only one wins and which one is not deterministic
- **Resetting one half of a two-variable piece of state desyncs the other half** — `open_()` cleared the `filter` property but not the `TextInput`'s own `text`, so reopening showed the previous query in the field while the list was filtered by an empty string
- **OPEN: no layer-rule blur is rendering in this session, and it is not quickshell's fault.** The `blur-quickshell` rule was added for 3.1 and does nothing — but `rofi`, which has had `blur-rofi` since Phase 0, fails the same control test, with terminal text behind it perfectly sharp. `decoration:blur` is enabled (size 6, 2 passes, `new_optimizations` true), `hyprctl configerrors` is empty, and `hyprctl reload` returns `ok`. Applying a rule at runtime via `hyprctl eval "hl.layer_rule({…})"` also returns `ok` and changes nothing observable — another `ok is not a result`. Session started 09:12:57, config edited 11:27, so the usual stale-session explanation applies and **this needs a relog to test properly**. Either blur regressed at some point in Phase 0 and was never re-checked, or 0.56.2's Lua build does not re-register layer rules on reload. Note `hyprctl layerrules` does not exist on this build ("unknown request"), so there is no way to read the rules back — `hyprctl keyword` is also refused ("keyword can't work with non-legacy parsers"). Worth a dedicated item.

## ⚡ Perf notes (GTX 1650 + Vega iGPU)

- Blur is the heaviest effect — if the 1650 ever renders the compositor, drop `size` to 4 / `passes` to 1 in `hyprland.lua`
- Force GTK/Qt apps onto the **Vega iGPU** via an `env` block if you see jank; leave browsers/Steam on the 1650
- cava in the bar is cheap (ASCII text), fine
- **The dashboard overlay holds no timers when closed** — its clock, the MPRIS tick and the 2s /proc poll are all `running: root.open`, so a summoned-once shell idles at zero. The one exception is the `blur-quickshell` layer rule, which is a *fullscreen* 2-pass blur whenever the overlay is up; if the 1650 ever renders the compositor, that is the first thing to drop (`ignore_alpha` back to 0.4, or delete the rule)

---

## How to use this file

- `[x]` done · `[~]` landed in the repo but still needs a live look on screen · `[ ]` not started
- Tick boxes as you land items
- New ideas go to the bottom of the matching phase
- Delete phases once fully done (Phase 0 kept as history)
