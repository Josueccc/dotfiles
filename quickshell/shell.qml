// shell.qml — Rizz dashboard overlay (roadmap 3.1, scope A)
//
// A summoned overlay: calendar, MPRIS media, system monitor, app launcher.
// It does NOT replace waybar or swaync. See RIZZ-ROADMAP.md 3.1 for why the
// "quickshell duplicates waybar" note was wrong, and quickshell/README.md for
// the traps this file deliberately works around.
//
// Roadmap 3.2 added two more things to the same file, both of which replace a
// shell-script hack with a real API:
//   · Services.UPower  — the power-profile row, which waybar's battery
//     left-click used to drive through a rofi picker (power-profile.sh).
//   · Services.Polkit — a real authentication agent. This machine previously had
//     NO polkit agent running at all (polkit-gnome is installed but was never
//     autostarted), so auth requests had nothing to show. See "Deliberately not
//     here" in the README for why that makes deleting pin-polkit safe.
//
        // editing this file needs a manual `quickshell` restart (no -c: this is the
        // 'default' config, and -c takes a config NAME, not a path) rather than hot
        // reload, which is the same trade this repo makes everywhere else.
// Toggle:  qs -c ~/.config/quickshell ipc call dashboard toggle
//          (bound to Super+D in hyprland/hyprland.lua)
//
// Written against quickshell 0.3.1. The API is versioned per-minor and this
// file is not compatible with 0.2.x without checking the type index.

// QtQuick is NOT implicit in 0.3.1 even though most quickshell examples omit
// it: without this import ListView fails to resolve at load time.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Polkit
import Quickshell.Services.UPower
import Quickshell.Widgets

PanelWindow {
    id: root

    // Nerd Font. Pinned by name, never "monospace": alacritty's family =
    // "monospace" resolves to Noto Sans Mono, which has no Nerd glyphs, and
    // the same mistake here would silently render every icon as tofu.
    readonly property string nf: "JetBrainsMono Nerd Font"

    // Full-screen layer surface, unmapped while closed. A layer-shell surface
    // with visible: false does not receive input, so this costs nothing and
    // gives click-anywhere-to-dismiss for free.
    //
    // The -c flag names the instance, so this surface exists on every monitor.
    // Only the focused one is interactive; the others are painted but inert.
    anchors { top: true; left: true; right: true; bottom: true }

    // A launcher that reserves screen edges is a bug, not a feature.
    // ExclusionMode is a top-level type in the Quickshell module, NOT nested
    // under the Quickshell singleton — Quickshell.ExclusionMode.Ignore throws
    // "cannot read property 'Ignore' of undefined" and leaves the window
    // reserving space anyway.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: true
    // Bound to `open`, NOT a literal false. Leaving this as a constant is the
    // quiet version of "ok is not a result": `qs ipc call dashboard open`
    // returns success, the function runs, and there is no overlay at all,
    // because nothing ever connected the state to the surface.
    //
    // OR the polkit prompt being live. Those are independent: an auth request
    // arrives from another program at an arbitrary moment, and tying it to
    // `open` would mean a polkit prompt is invisible unless the user happened
    // to have the dashboard open — which is the one situation where they are
    // guaranteed not to. So the surface is up when EITHER wants it, and the
    // two children below gate themselves on their own state.
    visible: open || polkit.flow !== null

    // ── State ────────────────────────────────────────────────────────────────
    property bool open: false
    property string filter: ""

    // Wall clock. SystemClock with Minute precision is enough (waybar already
    // carries the seconds in modules-center) and it costs one wakeup a minute
    // instead of one a second. enabled is bound to open so a hidden overlay
    // never ticks at all.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open
    }

    // MPRIS re-evaluation is driven off `tick` rather than off the player
    // properties: isPlaying/trackTitle change on the player's own schedule and
    // nothing in `mpris` reads them, so a pure binding would never re-run when
    // a track changes. See "A binding only re-runs on what it reads".
    property int tick: 0
    Timer {
        interval: 1000
        repeat: true
        running: root.open
        onTriggered: root.tick = root.tick + 1
    }

    // ── Palette ──────────────────────────────────────────────────────────────
    // Wallpaper-driven, exactly like every other app in the pipeline. The JSON
    // is written by wallust (wallust/templates/colors-quickshell.json).
    //
    // watchChanges means the dashboard follows the wallpaper with no restart and
    // no relog — strictly better than waybar, which apply-theme.sh kills and
    // restarts on every change. Seeding the values below means the overlay is
    // correct even if wallust has never run.
    FileView {
        id: pal
        path: Quickshell.shellPath("generated-colors.json")
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()

        // Assigned explicitly rather than relying on it being the default
        // property. NOTE: the id is `pal`, not `palette` — Qt already owns that
        // name (QQuickPalette), so an id of `palette` silently loses and every
        // colour below throws "cannot read property X of undefined".
        adapter: JsonAdapter {
            // Catppuccin Mocha, matching the seeds in wallust/apply-theme.sh.
            // The names and the source indices match colors-waybar.css on
            // purpose: one palette, one set of names, so the dashboard and the
            // bar cannot drift apart.
            property string base: "#1e1e2e"
            property string mantle: "#181825"
            property string crust: "#11111b"
            property string surface0: "#313244"
            property string surface1: "#45475a"
            property string surface2: "#585b70"
            property string overlay0: "#6c7086"
            property string subtext0: "#a6adc8"
            property string text: "#cdd6f4"
            property string blue: "#89b4fa"
            property string mauve: "#cba6f7"
            property string red: "#f38ba8"
            property string peach: "#fab387"
            property string yellow: "#f9e2af"
            property string green: "#a6e3a1"
            property string teal: "#94e2d5"
            property string sapphire: "#74c7ec"
            property string lavender: "#b4befe"
        }
    }

    // ── System monitor ───────────────────────────────────────────────────────
    // /proc directly, no helper process. Three FileViews reloaded on a timer
    // rather than one `sh -c` per tick: spawning a shell every 2s to cat three
    // files is the kind of thing that shows up in a profiler and nowhere else.
    property real cpuPercent: 0
    property real prevTotal: 0
    property real prevIdle: 0
    property string loadAvg: "—"

    FileView { id: statFile; path: "/proc/stat"; printErrors: false }
    FileView { id: memFile;  path: "/proc/meminfo"; printErrors: false }
    FileView { id: loadFile; path: "/proc/loadavg"; printErrors: false }

    // MemAvailable, not MemFree: on a modern kernel MemFree excludes page cache
    // and reads as ~0 on any machine that has ever done any I/O.
    readonly property real memPercent: {
        const t = memFile.text();
        if (!t) return 0;
        const total = /^MemTotal:\s+(\d+)/m.exec(t);
        const avail = /^MemAvailable:\s+(\d+)/m.exec(t);
        if (!total || !avail) return 0;
        return Math.round((1 - Number(avail[1]) / Number(total[1])) * 100);
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.open
        onTriggered: {
            // /proc/stat is cumulative jiffies, so a percentage needs two
            // samples. Read first, reload after: the text is one tick stale,
            // which at a 2s interval is a 2s window, not a wrong number.
            const raw = statFile.text();
            const line = raw ? raw.split("\n")[0] : "";
            if (line) {
                const f = line.split(/\s+/).slice(1).map(Number);
                const total = f.reduce((a, b) => a + b, 0);
                // field 3 is idle, field 4 is iowait — both are "not working"
                const idle = f[3] + (f[4] || 0);
                const dt = total - root.prevTotal;
                if (dt > 0) root.cpuPercent = Math.round((1 - (idle - root.prevIdle) / dt) * 100);
                root.prevTotal = total;
                root.prevIdle = idle;
            }
            const l = loadFile.text();
            if (l) root.loadAvg = l.trim().split(/\s+/)[0];
            statFile.reload();
            memFile.reload();
            loadFile.reload();
        }
    }

    // ── Media ────────────────────────────────────────────────────────────────
    // First playing player, else the first one MPRIS knows about.
    readonly property var mpris: {
        const _ = root.tick; // re-evaluate on the timer, see note above
        const all = Mpris.players.values;
        for (const p of all) if (p.isPlaying) return p;
        return all.length > 0 ? all[0] : null;
    }

    function fmtTime(secs) {
        if (!secs || secs < 0) return "0:00";
        const s = Math.floor(secs % 60);
        const m = Math.floor(secs / 60) % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ── Launcher ─────────────────────────────────────────────────────────────
    // DesktopEntries is an index, explicitly not usage-ranked, so an unfiltered
    // list is alphabetical and boring. Capping it is honest: it is a launcher
    // for typing into, not a menu you browse.
    readonly property var apps: {
        const q = root.filter.trim().toLowerCase();
        const all = DesktopEntries.applications.values;
        if (q === "") return all.slice(0, 40);
        return all.filter(a => (a.name || "").toLowerCase().indexOf(q) >= 0).slice(0, 40);
    }

    function launch(entry) {
        if (!entry) return;
        if (entry.runInTerminal) {
            // DesktopEntry.command does not open a terminal on its own, and
            // execDetached does not use a shell, so the terminal is ours to add.
            Quickshell.execDetached({ command: ["kitty", "-e"].concat(entry.command) });
        } else {
            Quickshell.execDetached({
                command: entry.command,
                workingDirectory: entry.workingDirectory
            });
        }
        root.close();
    }

    // ── Power profile (roadmap 3.2) ──────────────────────────────────────────
    // Services.UPower, which is power-profiles-daemon over D-Bus. This replaces
    // waybar/scripts/power-profile.sh, which shelled out to `powerprofilesctl`
    // behind a rofi dmenu. Same daemon either way, so this is not a capability
    // change — it is a rofi menu that follows the wallpaper like everything else
    // does, and one less process on the click path.
    readonly property var pp: PowerProfiles

    // PowerProfile is a 3-value enum: 0 = PowerSaver, 1 = Balanced,
    // 2 = Performance. There is no enum-value lookup exposed to QML (the
    // `toString` on the PowerProfile type is not reachable from the singleton —
    // PowerProfiles.toString() is the QObject one, which prints the object
    // pointer), so the names are spelled out here.
    //
    // `hasPerformanceProfile` is the important one, and it is a TRAP: it reads
    // false for the first few hundred milliseconds and then turns true, because
    // it is filled in by an async D-Bus reply. Verified by sampling it every
    // 300ms — false on tick 1, true from tick 2 on. It is also genuinely false
    // on hardware with no intel_pstate/amd_pstate, and setting Performance
    // there does not fail quietly: it logs "Cannot request performance profile
    // as it is not present for this device" and leaves the profile unchanged.
    //
    // So this cannot be read once at startup, and offering a button that cannot
    // work is worse than not offering it. Because it is a plain binding on a
    // real property, the row simply gains the Performance segment once the
    // answer arrives — no timer, no re-check.
    readonly property var profileOptions: {
        const opts = [
            { value: 0, label: "Saver",   glyph: "" },
            { value: 1, label: "Balanced", glyph: "" }
        ];
        if (pp.hasPerformanceProfile)
            opts.push({ value: 2, label: "Performance", glyph: "" });
        return opts;
    }

    function setPowerProfile(value) {
        // Guard rather than trust: the picker is the only caller and it only
        // offers what profileOptions contains, but an IPC call can set anything.
        if (pp.profile === value) return;
        pp.profile = value;
    }

    // Cycle, for the waybar battery click. Wraps over the *available* profiles
    // only, so on a machine with no Performance profile the cycle is
    // Balanced -> Saver -> Balanced instead of silently sticking on Balanced
    // when it lands on a value the hardware will not take.
    function cyclePowerProfile() {
        if (profileOptions.length === 0) return;
        const i = profileOptions.findIndex(o => o.value === pp.profile);
        // findIndex is -1 for an unknown current value (e.g. switched to
        // another daemon); start at 0 rather than indexing -1, which would
        // read undefined and set NaN.
        const next = profileOptions[(i + 1 + profileOptions.length) % profileOptions.length];
        setPowerProfile(next.value);
    }

    // ── Polkit (roadmap 3.2) ─────────────────────────────────────────────────
    // A real authentication agent. PolkitAgent is a QML ELEMENT, not a
    // singleton — writing `PolkitAgent.isRegistered` gives undefined, because
    // the bare name is the type, not an instance. This is the same shape of
    // trap as the `palette` id below: the object resolves, its properties do
    // not, and it reads like broken data rather than a name collision.
    PolkitAgent {
        id: polkit

        // isRegistered is FALSE in the first moments after load and true a
        // beat later (verified: false at Component.onCompleted, true by the
        // first 500ms tick). So this must not gate the prompt's visibility —
        // an auth request that lands in that window would be dropped, and
        // dropping it is exactly the failure the agent exists to prevent.
        onFlowChanged: {
            if (flow === null) return;
            // Park the query. The prompt has its own TextInput, and leaving a
            // stale password in it means the next request is pre-filled with
            // the last one typed.
            polkitPass.text = "";
            polkitPass.forceActiveFocus();
        }
    }

    function polkitSubmit() {
        if (polkit.flow === null) return;
        polkit.flow.submit(polkitPass.text);
    }
    function polkitCancel() {
        if (polkit.flow === null) return;
        polkit.flow.cancelAuthenticationRequest();
    }

    // ── Calendar ─────────────────────────────────────────────────────────────
    // Monday-first, matching the rest of the continent.
    readonly property var monthCells: {
        const d = clock.date;
        const y = d.getFullYear();
        const m = d.getMonth();
        const lead = (new Date(y, m, 1).getDay() + 6) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < lead; i++) cells.push(0);
        for (let i = 1; i <= days; i++) cells.push(i);
        while (cells.length % 7 !== 0) cells.push(0);
        return cells;
    }
    // The grid is always the current month, so matching the day number is
    // enough — no month/year comparison needed.
    readonly property var isToday: (day) => day !== 0 && day === clock.date.getDate()

    readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    // ── Open / close ─────────────────────────────────────────────────────────
    function open_() {
        open = true;
        // Both of these, not just one. Resetting `filter` alone leaves the
        // TextInput still showing the previous query while the list is filtered
        // by an empty string, because they are two separate pieces of state.
        search.text = "";
        filter = "";
        appList.currentIndex = 0;
        appList.positionViewAtBeginning();
        // Focus the TextInput itself rather than a proxy item, so it does its
        // own text editing — insertion, backspace, cursor, selection, Ctrl+U —
        // instead of this file reimplementing it badly.
        search.forceActiveFocus();
    }
    function close() { open = false; }

    Component.onCompleted: {
        // Quickshell.watchFiles defaults to true and reloads the WHOLE config
        // when any file in the shell directory changes. generated-colors.json
        // lives in that directory, so every wallpaper change would reload the
        // shell and slam the overlay shut — the palette FileView above already
        // handles that change without a reload. Off it is; the cost is that
        // editing this file needs a manual `quickshell` restart (no -c: this is the
        // 'default' config, and -c takes a config NAME, not a path) rather than hot
        // reload, which is the same trade this repo makes everywhere else.
        Quickshell.watchFiles = false;
    }

    // ── IPC ──────────────────────────────────────────────────────────────────
    // The toggle. A plain `qs ipc call` from a Hyprland bind was chosen over
    // Quickshell.Hyprland.GlobalShortcut on purpose: GlobalShortcut needs a
    // `global` bind whose Lua form is not verified on this machine, and a
    // dispatcher that silently does nothing is the exact failure this repo has
    // already been bitten by twice. The exec_cmd form below is used 20-odd
    // times already and is known to fire.
    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.open ? root.close() : root.open_(); }
        function open(): void { root.open_(); }
        function close(): void { root.close(); }
    }

    // Separate target, not more functions on `dashboard`. The waybar battery
    // click needs the profile to change WITHOUT the overlay appearing — a
    // `dashboard toggle` there would slam the full-screen overlay open on
    // every battery click, which is the opposite of a cycle. Same reason
    // `qs ipc call` returns nothing useful: what matters is that the call
    // fires, and the profile row re-renders off the profileChanged signal.
    IpcHandler {
        target: "power"
        function cycle(): void { root.cyclePowerProfile(); }
        function set(v: int): void { root.setPowerProfile(v); }
    }

    // ── Painting ─────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        // Gated on `open`, not just present. The window is mapped whenever a
        // polkit flow is live, and without this a click anywhere on the prompt
        // would fall through to here and dismiss the dashboard — which the
        // user cannot see — leaving a polkit prompt on screen that eats their
        // clicks and looks frozen.
        enabled: root.open
        onClicked: root.close()
    }

    Rectangle {
        id: card
        visible: root.open
        anchors.centerIn: parent
        width: 1040
        height: 600
        radius: 16
        // Themed and near-opaque. A flat rgba(0,0,0,0.55) was tried first and
        // is far too see-through: it sits over a *terminal*, so every glyph
        // behind it stays legible and the header text competes with the window
        // underneath. Alpha on the palette's own base keeps it themed without
        // going grey.
        color: Qt.alpha(pal.adapter.base, 0.93)
        border.width: 1
        border.color: pal.adapter.blue

        // Swallow clicks so they do not reach the dismiss MouseArea behind.
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header: clock + hint
            Item {
                width: parent.width
                height: 44

                Text {
                    id: bigClock
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: pal.adapter.text
                    font.family: root.nf
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.left: bigClock.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    color: pal.adapter.subtext0
                    font.family: root.nf
                    font.pixelSize: 13
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // U+F002 magnifier — carried over from the tmux template,
                    // where it is the one glyph verified against a rendered
                    // sheet rather than a codepoint name.
                    text: "search  type to filter      esc  close"
                    color: pal.adapter.overlay0
                    font.family: root.nf
                    font.pixelSize: 11
                }
            }

            Row {
                width: parent.width
                height: parent.height - 58
                spacing: 14

                // ── Column 1: calendar ───────────────────────────────────
                Rectangle {
                    width: 300; height: parent.height
                    radius: 12
                    color: pal.adapter.mantle

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            text: Qt.formatDateTime(clock.date, "MMMM yyyy")
                            color: pal.adapter.mauve
                            font.family: root.nf
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        Row {
                            Repeater {
                                model: root.weekdays
                                Text {
                                    required property var modelData
                                    width: 40; text: modelData
                                    horizontalAlignment: Text.AlignHCenter
                                    color: pal.adapter.overlay0
                                    font.family: root.nf
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Grid {
                            columns: 7
                            Repeater {
                                model: root.monthCells
                                Text {
                                    required property var modelData
                                    required property int index
                                    width: 40; height: 30
                                    text: modelData === 0 ? "" : modelData
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    color: modelData === 0 ? "transparent"
                                         : root.isToday(modelData) ? pal.adapter.crust
                                         : pal.adapter.text
                                    // "today" is a filled pill, so its text has
                                    // to flip to the surface colour or it is
                                    // accent-on-accent.
                                    font.family: root.nf
                                    font.pixelSize: 12
                                    font.weight: root.isToday(modelData) ? Font.Bold : Font.Normal
                                    // The pill is a sibling declared AFTER this
                                    // Text, so without an explicit z it paints
                                    // on top and the number disappears. Sibling
                                    // order is paint order in QML.
                                    z: 1

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        radius: 6
                                        visible: root.isToday(modelData)
                                        color: pal.adapter.blue
                                    }
                                }
                            }
                        }

                        Item { width: 1; height: 1 }
                    }
                }

                // ── Column 2: launcher ───────────────────────────────────
                Rectangle {
                    width: 400; height: parent.height
                    radius: 12
                    color: pal.adapter.mantle

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        TextInput {
                            id: search
                            width: parent.width
                            height: 34
                            color: pal.adapter.text
                            font.family: root.nf
                            font.pixelSize: 14
                            selectionColor: pal.adapter.blue
                            selectedTextColor: pal.adapter.crust
                            clip: true
                            // No TextField: QtQuick.Controls would drag in the
                            // Fusion style, and a launcher that inherits the
                            // system style is the one thing in this overlay
                            // that would not follow the wallpaper.
                            onTextChanged: {
                                root.filter = text;
                                appList.currentIndex = 0;
                                appList.positionViewAtBeginning();
                            }

                            // Navigation keys only. Everything else is left
                            // UNACCEPTED on purpose, which hands the key back to
                            // the TextInput so it inserts the character itself.
                            //
                            // The first version did the opposite: a catch-all
                            // `else { search.text = event.text }`, which
                            // REPLACED the whole query with a single character,
                            // so typing "kit" left only "t" on screen. It reads
                            // like the field losing focus, not like a string
                            // being overwritten, which is why it survived review.
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    root.close();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return
                                        || event.key === Qt.Key_Enter) {
                                    root.launch(root.apps[appList.currentIndex]);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (appList.count > 0)
                                        appList.currentIndex = (appList.currentIndex + 1) % appList.count;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    if (appList.count > 0)
                                        appList.currentIndex =
                                            (appList.currentIndex - 1 + appList.count) % appList.count;
                                    event.accepted = true;
                                }
                                // No else branch. Falling through IS the fix.
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text.length === 0
                                text: "Filter applications…"
                                color: pal.adapter.overlay0
                                font: search.font
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: pal.adapter.surface1 }

                        ListView {
                            id: appList
                            width: parent.width
                            height: parent.height - 46
                            clip: true
                            model: root.apps
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 2

                            // No ScrollBar: it lives in QtQuick.Controls, and
                            // importing Controls is the one thing that would
                            // put a non-wallpaper style in this overlay. The
                            // list flicks and the wheel works without it.

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: appList.width
                                height: 38
                                radius: 8
                                color: index === appList.currentIndex
                                    ? pal.adapter.surface0 : "transparent"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    // An entry with no Icon= key is normal, not
                                    // broken. Fall back to a letter rather than
                                    // an empty hole or a "missing texture" box.
                                    // iconPath's check flag returns "" instead
                                    // of a missing-texture URL; IconImage has no
                                    // fill/smooth/color, it pads to 1:1 itself.
                                    IconImage {
                                        visible: modelData.icon !== ""
                                        source: Quickshell.iconPath(modelData.icon, true)
                                        width: 22; height: 22
                                        asynchronous: true
                                    }
                                    Rectangle {
                                        visible: modelData.icon === ""
                                        width: 22; height: 22; radius: 5
                                        color: pal.adapter.surface1
                                        Text {
                                            anchors.centerIn: parent
                                            text: (modelData.name || "?").charAt(0).toUpperCase()
                                            color: pal.adapter.text
                                            font.family: root.nf
                                            font.pixelSize: 12
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: pal.adapter.text
                                        font.family: root.nf
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.launch(modelData)
                                }
                            }
                        }
                    }
                }

                // ── Column 3: media + monitor ────────────────────────────
                Column {
                    width: 282
                    height: parent.height
                    spacing: 14

                    // Media
                    Rectangle {
                        width: parent.width; height: 250
                        radius: 12
                        color: pal.adapter.mantle

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "NOW PLAYING"
                                color: pal.adapter.overlay0
                                font.family: root.nf
                                font.pixelSize: 10
                            }

                            // Album art. MPRIS art is a URL and in practice
                            // almost always file://; Qt's Image will not fetch
                            // http(s) without extra plumbing, so remote art is
                            // skipped rather than shown as a broken image.
                            Image {
                                width: parent.width; height: 118
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: root.mpris !== null
                                    && root.mpris.trackArtUrl !== ""
                                    && root.mpris.trackArtUrl.indexOf("file://") === 0
                                source: visible ? root.mpris.trackArtUrl : ""
                                sourceSize.width: 240
                            }

                            Text {
                                width: parent.width
                                text: root.mpris === null ? "Nothing playing"
                                    : (root.mpris.trackTitle || "Unknown Title")
                                color: pal.adapter.text
                                font.family: root.nf
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.mpris === null ? "—"
                                    : (root.mpris.trackArtist || "Unknown Artist")
                                color: pal.adapter.subtext0
                                font.family: root.nf
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Item { width: 1; height: 1 }

                            Row {
                                spacing: 10
                                Repeater {
                                    model: [
                                        { glyph: "", fn: "previous", can: "canGoPrevious" },
                                        { glyph: "", fn: "togglePlaying", can: "canTogglePlaying" },
                                        { glyph: "", fn: "next", can: "canGoNext" }
                                    ]
                                    Text {
                                        required property var modelData
                                        text: modelData.glyph
                                        color: root.mpris !== null && root.mpris[modelData.can]
                                            ? pal.adapter.text : pal.adapter.overlay0
                                        font.family: root.nf
                                        font.pixelSize: 15
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            onClicked: {
                                                if (root.mpris === null) return;
                                                if (!root.mpris[modelData.can]) return;
                                                // canGoPrevious etc. are the guard
                                                // the MPRIS docs ask for; calling
                                                // the method anyway throws.
                                                root.mpris[modelData.fn]();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // System
                    Rectangle {
                        width: parent.width
                        height: parent.height - 264
                        radius: 12
                        color: pal.adapter.mantle

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                text: "SYSTEM"
                                color: pal.adapter.overlay0
                                font.family: root.nf
                                font.pixelSize: 10
                            }

                            Repeater {
                                model: [
                                    { label: "CPU", value: root.cpuPercent, c: pal.adapter.peach },
                                    { label: "RAM", value: root.memPercent, c: pal.adapter.mauve }
                                ]
                                Column {
                                    required property var modelData
                                    width: parent.width
                                    spacing: 4

                                    // An Item, not a Row: a Row positions its
                                    // children itself and warns (loudly, and
                                    // fatally — "Row will not function") if one
                                    // of them also sets anchors.
                                    Item {
                                        width: parent.width
                                        height: 16
                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            color: pal.adapter.subtext0
                                            font.family: root.nf
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.value + "%"
                                            color: pal.adapter.text
                                            font.family: root.nf
                                            font.pixelSize: 12
                                        }
                                    }

                                    // A bar with no track behind it reads as a
                                    // filled pill, so the track is explicit.
                                    Rectangle {
                                        width: parent.width; height: 6; radius: 3
                                        color: pal.adapter.surface1
                                        Rectangle {
                                            width: Math.max(2, parent.width * modelData.value / 100)
                                            height: parent.height; radius: 3
                                            color: modelData.c
                                            Behavior on width {
                                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 16
                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Load"
                                    color: pal.adapter.subtext0
                                    font.family: root.nf
                                    font.pixelSize: 12
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.loadAvg
                                    color: pal.adapter.text
                                    font.family: root.nf
                                    font.pixelSize: 12
                                }
                            }

                            // Power profile (roadmap 3.2). Sits under Load
                            // because it is the only row here that is a
                            // control rather than a reading.
                            //
                            // Label above, cells below, rather than sharing a
                            // line: with Performance available the three
                            // labels need ~230px and the column is 258, so
                            // "Power" and the control on one row is an
                            // overflow that only appears on machines that
                            // HAVE the performance profile — i.e. it would
                            // look fine on this one and break on a laptop.
                            Item {
                                id: powerRow
                                width: parent.width
                                height: 48

                                Text {
                                    id: powerTitle
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    text: "Power"
                                    color: pal.adapter.subtext0
                                    font.family: root.nf
                                    font.pixelSize: 12
                                }

                                // A hold pins the profile, and a hold is
                                // exactly the case where a control that lies
                                // is worst: the profile is right, the app that
                                // set it is not us, and the row would claim
                                // otherwise. Say so instead.
                                Text {
                                    anchors.left: powerTitle.right
                                    anchors.leftMargin: 8
                                    anchors.baseline: powerTitle.baseline
                                    visible: root.pp.holds.length > 0
                                    // Indexed, not mapped-and-joined: holds is
                                    // empty on this machine, so every path that
                                    // reads holds[0] has to be unreachable when
                                    // it is empty. A ternary on length>1 alone
                                    // still falls through to holds[0] at
                                    // length 0 and throws
                                    // "Cannot read property 'applicationId' of
                                    // undefined" — which is what it did.
                                    text: {
                                        const h = root.pp.holds;
                                        if (h.length === 0) return "";
                                        if (h.length > 1) return h.length + " apps";
                                        return "held by "
                                            + (h[0].applicationId || "another app");
                                    }
                                    color: pal.adapter.yellow
                                    font.family: root.nf
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    // Bound so a long applicationId cannot push
                                    // the row wider than the card.
                                    width: Math.min(implicitWidth,
                                                    powerRow.width - powerTitle.width - 8)
                                }

                                // Segmented control, below the label. Cells are
                                // an equal split of the row width rather than
                                // sized to their labels, so the control is the
                                // same width with two profiles or three.
                                Row {
                                    id: powerSegs
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 24
                                    spacing: 4

                                    Repeater {
                                        model: root.profileOptions
                                        Rectangle {
                                            required property var modelData
                                            readonly property bool active:
                                                root.pp.profile === modelData.value

                                            // Equal split, minus the gaps. Not
                                            // implicitWidth: a three-profile
                                            // row is wider than the card.
                                            width: (powerSegs.width - powerSegs.spacing
                                                    * (root.profileOptions.length - 1))
                                                    / root.profileOptions.length
                                            height: powerSegs.height
                                            radius: 6
                                            color: active ? pal.adapter.blue
                                                            : pal.adapter.surface0

                                            Behavior on color {
                                                ColorAnimation { duration: 160 }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                width: parent.width
                                                text: modelData.label
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                // Accent-on-accent otherwise, the
                                                // same flip the today-pill needs.
                                                color: parent.active ? pal.adapter.crust
                                                                    : pal.adapter.subtext0
                                                font.family: root.nf
                                                font.pixelSize: 11
                                                font.weight: parent.active ? Font.DemiBold
                                                                            : Font.Normal
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.setPowerProfile(modelData.value)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Polkit prompt ────────────────────────────────────────────────────────
    // Sibling of `card`, declared after it, so it paints on top. It is visible
    // purely off the flow, NOT off `root.open`: a polkit request comes from
    // some other program and has to be answerable while the dashboard is
    // closed. Binding it to `open` would mean the prompt is invisible exactly
    // when it is needed.
    Rectangle {
        id: pkCard
        visible: polkit.flow !== null
        anchors.centerIn: parent
        width: 420
        height: pkColumn.implicitHeight + 44
        radius: 16
        color: Qt.alpha(pal.adapter.base, 0.97)
        border.width: 1
        border.color: pal.adapter.mauve

        // Swallow clicks. The dismiss MouseArea behind is disabled while a
        // flow is live, but only for THIS window's own handler — a click here
        // must not reach anything behind it either.
        MouseArea { anchors.fill: parent }

        Column {
            id: pkColumn
            anchors.centerIn: parent
            width: parent.width - 44
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                // actionId, not a fixed glyph. Polkit's iconName is empty for
                // most actions (verified: org.freedesktop.policykit.exec sends
                // ""), so an Image bound to it would render nothing at all —
                // the same "defined but its properties are missing" shape as
                // the palette id trap.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌆"
                    color: pal.adapter.mauve
                    font.family: root.nf
                    font.pixelSize: 20
                }

                Column {
                    width: parent.width - 30
                    spacing: 2

                    Text {
                        width: parent.width
                        text: "Authentication required"
                        color: pal.adapter.text
                        font.family: root.nf
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        // Polkit supplies a human sentence here, e.g.
                        // "Authentication is needed to run `/usr/bin/true' as
                        // the super user". It is the reason the request exists,
                        // so it is the prompt's headline, not a detail.
                        text: polkit.flow !== null ? polkit.flow.message : ""
                        color: pal.adapter.subtext0
                        font.family: root.nf
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Identity picker, only when there is a choice to make. With one
            // identity (the common case, and this machine's case) polkit has
            // already selected it, so a picker here is a control with nothing
            // to do.
            Repeater {
                model: polkit.flow !== null && polkit.flow.identities.length > 1
                    ? polkit.flow.identities : []
                Rectangle {
                    required property var modelData
                    readonly property bool active:
                        polkit.flow !== null
                        && polkit.flow.selectedIdentity === modelData

                    width: pkColumn.width
                    height: 30
                    radius: 6
                    color: active ? pal.adapter.surface1 : "transparent"
                    border.width: 1
                    border.color: active ? pal.adapter.mauve : pal.adapter.surface0

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.displayName
                        color: pal.adapter.text
                        font.family: root.nf
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: polkit.flow.selectedIdentity = modelData
                    }
                }
            }

            // Password field. isResponseRequired is false when polkit is only
            // asking which identity to use, and showing an empty password box
            // then implies a credential is wanted when none is.
            Column {
                width: parent.width
                spacing: 6
                visible: polkit.flow !== null && polkit.flow.isResponseRequired

                Text {
                    text: polkit.flow !== null && polkit.flow.inputPrompt !== ""
                        ? polkit.flow.inputPrompt : "Password"
                    color: pal.adapter.subtext0
                    font.family: root.nf
                    font.pixelSize: 11
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 8
                    color: pal.adapter.mantle
                    border.width: 1
                    // Crust on focus, so the focused field is the one with a
                    // visible ring without needing a focus-scope.
                    border.color: polkitPass.activeFocus ? pal.adapter.mauve
                                                          : pal.adapter.surface1

                    TextInput {
                        id: polkitPass
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: pal.adapter.text
                        font.family: root.nf
                        font.pixelSize: 14
                        selectionColor: pal.adapter.mauve
                        selectedTextColor: pal.adapter.crust
                        echoMode: TextInput.Password
                        clip: true

                        // Same rule as the launcher filter: handle the keys you
                        // want, leave the rest UNACCEPTED so the field does its
                        // own text editing. A catch-all else that assigns
                        // event.text destroys the input — see the README.
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.polkitCancel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return
                                    || event.key === Qt.Key_Enter) {
                                root.polkitSubmit();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            // Polkit's own supplementary text, and its own error flag. This is
            // where "Authentication failed" lands, so it must not be styled as
            // ordinary help text or a failed login looks like a success.
            Text {
                width: parent.width
                visible: polkit.flow !== null
                    && polkit.flow.supplementaryMessage !== ""
                text: polkit.flow !== null ? polkit.flow.supplementaryMessage : ""
                color: polkit.flow !== null && polkit.flow.supplementaryIsError
                    ? pal.adapter.red : pal.adapter.subtext0
                font.family: root.nf
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: pkCancel.implicitWidth + 26
                    height: 32
                    radius: 8
                    color: pal.adapter.surface0
                    Text {
                        id: pkCancel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: pal.adapter.subtext0
                        font.family: root.nf
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.polkitCancel()
                    }
                }

                Rectangle {
                    width: pkOk.implicitWidth + 26
                    height: 32
                    radius: 8
                    color: polkit.flow !== null && polkit.flow.isResponseRequired
                        ? pal.adapter.mauve : pal.adapter.surface1
                    Text {
                        id: pkOk
                        anchors.centerIn: parent
                        text: "Authenticate"
                        // On a mauve button the label has to flip, same as
                        // the power segments and the today pill.
                        color: polkit.flow !== null && polkit.flow.isResponseRequired
                            ? pal.adapter.crust : pal.adapter.overlay0
                        font.family: root.nf
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.polkitSubmit()
                    }
                }
            }
        }
    }

    // There is deliberately no `focus: root.open` proxy Item here any more.
    // Two items both claiming focus is a silent, intermittent bug waiting to
    // happen: the TextInput has the real focus, so this one would only ever
    // steal key events from it. Keyboard handling lives on `search` instead.
}
