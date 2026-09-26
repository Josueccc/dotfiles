// shell.qml — Rizz dashboard overlay (roadmap 3.1, scope A)
//
// A summoned overlay: calendar, MPRIS media, system monitor, app launcher.
// It does NOT replace waybar or swaync. See RIZZ-ROADMAP.md 3.1 for why the
// "quickshell duplicates waybar" note was wrong, and quickshell/README.md for
// the traps this file deliberately works around.
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
    visible: open

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

    // ── Painting ─────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
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
                        }
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
