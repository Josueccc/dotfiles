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

**A catch-all `else` in a `Keys` handler silently destroys text input.** The
first version routed every unhandled key with `search.text = event.text`, which
*replaces* the query with one character — typing "kit" left "t" on screen. It
reproduces on the very first keypress, but it reads like the field losing focus
rather than a string being overwritten, which is how it got shipped. The rule:
a `Keys` handler should handle only the keys it wants and leave the rest
**unaccepted**, so the focused item does its own text editing. `Keys.onPressed`
on the `TextInput` itself, plus `search.forceActiveFocus()`, also means
backspace, cursor movement, selection and Ctrl+U come for free.

**Two items both claiming focus is a silent bug.** There was a proxy `Item` with
`focus: root.open` sitting alongside the `TextInput`. Only one item can hold
focus, and the wrong one winning intermittently is the worst shape of bug.
Deleted — the `TextInput` takes focus directly and the proxy is gone.

**Resetting one half of a two-variable piece of state desyncs the other half.**
`open_()` cleared `filter` but not `search.text`, so reopening showed the
previous query in the field while the list was filtered by an empty string.

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

## Services added in roadmap 3.2

Two more traps, both of which read as *hardware facts* and are not:

**`PolkitAgent` is an element, not a singleton.** `PolkitAgent.isRegistered`
evaluates to `undefined`, not `false` — the bare name is the type, and a type has
no instance properties. Declare it: `PolkitAgent { id: polkit }`. This is the
same shape as the `palette` id trap above (object resolves, properties do not),
which is why it is worth writing down twice.

**`isRegistered` is false at startup and true a moment later.** Verified by
sampling every 500ms: false in the first tick, true from the second. Nothing is
wrong. But it means **`isRegistered` must not gate anything that drops work** —
an auth request landing in that window would be silently dropped, which is the
one failure the agent exists to prevent. Gate on `flow`, which only ever
becomes non-null when there is genuinely something to show.

**`PowerProfiles.hasPerformanceProfile` has the same race, and it is worse.**
It reads `false` for the first ~300ms and then turns `true`. Probed by
sampling: false on tick 1, true from tick 2 onward, on this machine — which
does have a Performance profile. An early read says "this desktop has no
performance profile" and that conclusion is simply wrong. Never snapshot this
into a local at startup; bind to it, and let the row gain the segment when the
answer lands. (`PerformanceProfile` genuinely does not exist on hardware
without intel_pstate/amd_pstate, and setting it there logs an error and
silently no-ops, so the guard is worth having — just not worth caching.)

**`PowerProfiles.holds` is a `QList<PowerProfileHold*>`, and a ternary on
length alone is not a guard.** `holds.length > 1 ? ... : holds[0].x` still
evaluates `holds[0]` at length 0 and throws "Cannot read property
'applicationId' of undefined". Every path that indexes must be unreachable
when the list is empty. The binding is now a statement block that returns `""`
first.

**`Identity` is not in the type index, but its properties work.**
`flow.identities` is typed `QList<Identity*>` and no
`Quickshell.Services.Polkit/Identity` is exported, so the type index says the
properties are unreachable. They are not — probed live against a real
`pkexec` request: `identities[0].displayName` → `"josue"`, `identities[0].id`
→ `1000`. The index is generated from exported metatypes and this one is
inherited rather than declared, so it is absent from the index and present at
runtime. Worth knowing before deciding a thing is impossible.

**Polkit's `iconName` is usually empty.** `org.freedesktop.policykit.exec`
sends `""` (verified). An `Image` bound to it renders nothing at all, silently.
The prompt uses a fixed glyph instead.

## Verified

- Overlay opens/closes over IPC; `qs ipc show` lists the target.
- Calendar month grid, today pill, Monday-first.
- Launcher filter, icons, selection highlight, scrolling.
- MPRIS: verified against VLC. The `trackTitle || "Unknown Title"` fallbacks
  and the `canGoPrevious` / `canTogglePlaying` / `canGoNext` capability gates
  both do the right thing.
- System monitor: CPU, RAM (`MemAvailable`, not `MemFree`), load average.
- **Keyboard, all of it**, driven with real key events:
  `hyprctl eval "hl.dispatch(hl.dsp.send_shortcut({ mods = '', key = 'k' }))"`
  — type-to-filter (`kit` → one result), Backspace (`ki`), Up/Down moving the
  highlight 0→1→2→1, Escape closing, and Enter launching (a real kitty window
  appeared, `hyprctl clients` 1→2, and the overlay closed). No `wtype`/`ydotool`
  needed; see the session notes in RIZZ-ROADMAP.md.
- **Palette follows the wallpaper live, with no restart** — re-themed while the
  shell was running and every accent changed, verified by pixel-sampling
  (`R=G=B` on a greyscale wallpaper's palette).

### Roadmap 3.2

- **Power profile, both paths.** `qs ipc call power cycle` walks
  balanced → performance → power-saver → balanced, confirmed against
  `powerprofilesctl get` after each step. The SYSTEM card's segmented row
  renders all three segments with the active one filled, and the Performance
  segment appears on its own once `hasPerformanceProfile` settles — no restart.
- **Polkit, end to end, with the dashboard closed.** A real `pkexec true`
  request produced the prompt as a layer surface on top of a terminal:
  polkit's own message, a focused password field, Cancel/Authenticate. Real key
  events typed into it (`echoMode: Password`, seven dots for "wrongpw"), Enter
  submitted, and polkit's `supplementaryMessage` rendered — it rate-limited to
  *"(10 minutes left to unlock)"*. Escape cancelled and `pkexec` exited.

## Not verified

- **The blur layer rule.** `hyprland.lua` adds `blur-quickshell` for this
  namespace, but no layer-rule blur is rendering in the session this was built
  in — `rofi` fails the same control test, and the rules have been in the
  config since Phase 0. So this is *not* specific to quickshell; see the
  session notes. The card is built to be legible without it: measured
  `(24,24,37)` inside, i.e. fully opaque, not the see-through mess a naive
  `rgba(0,0,0,0.55)` gives over a terminal.
- **Multi-monitor.** The `PanelWindow` is anchored to all four edges and so
  spans every output, but only one monitor has been used.
- **`Super+D` itself.** `hyprctl binds` shows the bind registered as
  `dispatcher: __lua`, and the command it runs is verified by hand, but firing
  it needs a real keypress — `send_shortcut` delivers to the focused *client*,
  not through the bind dispatcher.
- **A successful polkit authentication.** Everything up to and including a
  *failed* submit is verified above; granting the credential needs a real
  password, which is not something to type into a test. So
  `authenticationSucceeded`, `isSuccessful` and the flow clearing itself on
  success are unexercised.
- **The polkit identity picker.** It is gated on `identities.length > 1` and
  this machine has exactly one identity (`displayName: "josue"`), so the
  branch never renders here. The properties it reads *are* verified — see the
  traps above — but the click-to-select behaviour is not.
- **`pp.holds` rendering.** The "held by …" line is gated on a non-empty
  `holds` list, which is empty on this machine (no app has taken a hold), so it
  has never been seen on screen. This is also the one binding that first shipped
  broken: a ternary on `length > 1` still indexes `holds[0]` at length 0 and
  throws. It is fixed and the load is clean, but the *rendered* state is unseen.

## Deliberately not here

`QtQuick.Controls` is not imported, so there is no `TextField` and no
`ScrollBar` — the filter is a bare `TextInput` and the list flicks without a
visible scrollbar. Importing Controls brings the Fusion style with it, and a
launcher that inherits the system style is the one surface in this overlay that
would not follow the wallpaper. The polkit password field and the power
segments are built the same way, for the same reason.

The polkit prompt has no window title, no icon and no taskbar entry, because it
is not a window. Anything that reaches for one — a rule matching
`.*-authentication-agent-1$`, a script looking for a client class — will not
find it. That is the point, but it is also why the `pin-polkit` rule was
removed rather than left to match nothing.
