# quickshell — dashboard overlay

The roadmap 3.1 overlay: calendar, MPRIS media, system monitor, app launcher,
summoned with `Super+D`. It is an **overlay, not a shell** — waybar and swaync
stay exactly as they are. See `RIZZ-ROADMAP.md` 3.1 for why the original
"quplicates waybar for no gain" note was half right.

Everything is in `shell.qml`. One file on purpose: sub-components in separate
files cannot see the root object's `id`, and passing a palette down through
every one of them is more machinery than a launcher earns.

## Running it

    quickshell                      # the 'default' config, this one
    qs ipc call dashboard toggle    # what Super+D runs
    qs ipc call dashboard open|close
    qs ipc show                     # list IPC targets (proves it loaded)

Autostarted from `hyprland/hyprland.lua` on `hyprland.start`, and bound to
`Super+D` there too. Palette comes from `wallust` via
`wallust/templates/colors-quickshell.json` → `generated-colors.json`.

## Traps, in the order they cost time

**An `id` can silently lose to a Qt-internal type.** The palette `FileView` was
originally `id: palette`. `palette.adapter` was then undefined in every binding
— 1322 `TypeError: Cannot read property 'X' of undefined` warnings — while
logging `Component.onCompleted` showed the adapter *perfectly alive*. The cause:
Qt already owns the name. Binding it printed
`QQuickPalette(0x…)` instead of the FileView. Any QML file naming an id
`palette` is silently referring to something else. It is now `pal`. The tell is
that the object is defined but its *properties* are missing, which reads like a
broken data file rather than a name collision.

**`ExclusionMode` is a top-level type, not a member of the `Quickshell`
singleton.** `Quickshell.ExclusionMode.Ignore` throws "cannot read property
'Ignore' of undefined". Correct form: `ExclusionMode.Ignore`.

**`QtQuick` is not an implicit import**, even though most quickshell examples
omit it. Without it, `ListView is not a type` at load.

**A `Row` warns fatally if a child also sets anchors.** `anchors.right` inside
a `Row` gives "Row will not function" and the row stops laying out. Use an
`Item` wrapper when one side needs to be right-aligned.

**Sibling order is paint order.** The calendar's "today" pill is a `Rectangle`
sibling of the day-number `Text`; declared after it, the pill painted over its
own number and the current date was invisible. The pill needs an explicit
`z: -1`, or the `Text` a `z: 1`.

**`visible: false` on the window, with state held in a separate property, shows
nothing.** The first working-looking version had `property bool open` and a
literal `visible: false`. `qs ipc call dashboard open` returned success, the
function ran, and there was no overlay — because nothing connected `open` to
`visible`. This is the "ok is not a result" failure in a new costume: a
successful IPC call is not a visible window.

**`Quickshell.watchFiles` defaults to true and reloads the whole config when
any file in the shell directory changes.** `generated-colors.json` lives in that
directory, so every wallpaper change would reload the shell and slam the overlay
shut. It is set to `false` in `Component.onCompleted`; the palette `FileView`
handles that change without a reload. The cost is that editing `shell.qml`
needs a manual `quickshell` restart rather than hot reload.

**`JsonAdapter` properties are seeded from QML, then overwritten by the file.**
Logging them in `Component.onCompleted` shows the *fallback* values even though
the file has loaded — the adapter applies file contents after load. Do not
conclude the palette file is broken from an early read.

**A CPU percentage needs two samples.** `/proc/stat` is cumulative jiffies, so
the first timer tick can only record a baseline. The dashboard shows `0%` for
the first two seconds, which looks like a broken monitor and is not.

## Verified

- Overlay opens/closes over IPC; `qs ipc show` lists the target.
- Calendar month grid, today pill, Monday-first.
- Launcher filter, icons, selection highlight, scrolling.
- MPRIS: verified against VLC. The `trackTitle || "Unknown Title"` fallbacks
  and the `canGoPrevious` / `canTogglePlaying` / `canGoNext` capability gates
  both do the right thing.
- System monitor: CPU, RAM (`MemAvailable`, not `MemFree`), load average.
- **Palette follows the wallpaper live, with no restart** — re-themed while the
  shell was running and every accent changed, verified by pixel-sampling
  (`R=G=B` on a greyscale wallpaper's palette).

## Not verified

- **Keyboard.** `Escape` / arrows / `Enter` / type-to-filter are wired through
  `Keys.onPressed` and the `TextInput`, but no synthetic-keyboard tool is
  installed on this machine (`wtype` and `ydotool` both absent), so it has not
  been exercised. Needs a human at the keyboard.
- **The blur layer rule.** `hyprland.lua` adds `blur-quickshell` for this
  namespace, but no layer-rule blur is rendering in the session this was built
  in — `rofi` fails the same control test, and the rules have been in the
  config since Phase 0. So this is *not* specific to quickshell; see the
  session notes. The card is built to be legible without it: measured
  `(24,24,37)` inside, i.e. fully opaque, not the see-through mess a naive
  `rgba(0,0,0,0.55)` gives over a terminal.
- **Multi-monitor.** The `PanelWindow` is anchored to all four edges and so
  spans every output, but only one monitor has been used.

## Deliberately not here

`QtQuick.Controls` is not imported, so there is no `TextField` and no
`ScrollBar` — the filter is a bare `TextInput` and the list flicks without a
visible scrollbar. Importing Controls brings the Fusion style with it, and a
launcher that inherits the system style is the one surface in this overlay that
would not follow the wallpaper.
