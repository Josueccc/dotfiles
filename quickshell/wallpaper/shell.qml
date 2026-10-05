// shell.qml — the wallpaper carousel (roadmap 4.1 / 5.1). Super+W.
//
// A slanted strip of cards: the current one opens up to 16:9 and plays the
// video if it is one, the rest are thin slices. Replaces the rofi grid.
//
// Its own process, like the lock: `quickshell -p ~/.config/quickshell/wallpaper`,
// started by waybar/scripts/wallpaper-picker.sh and gone again the moment a
// wallpaper is picked or Escape is pressed. So it idles at nothing — no daemon,
// no timers — and a crash here cannot take the dashboard's polkit agent down.
//
// It does not set anything itself. A pick is handed to wallpaper.sh, which owns
// the image-vs-video logic and the re-theming; the same script lists the files
// and makes the thumbnails, so this file never touches a 4K original except for
// the one card in the middle.
//
// Same traps as the dashboard (quickshell/README.md): QtQuick is imported
// explicitly, the palette id is `pal`, and QtQuick.Controls is NOT imported —
// the search box is a bare TextInput, so nothing here can pick up a system
// style that does not follow the wallpaper.
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property string nf: "JetBrainsMono Nerd Font"
    readonly property string script:
        Quickshell.env("HOME") + "/.config/waybar/scripts/wallpaper.sh"

    // The launcher passes the focused monitor in, rather than this file binding
    // to Hyprland.focusedMonitor: that one is null until the IPC socket has
    // answered, so a binding would map the window on screens[0] first and then
    // jump. An env var is known before the first frame.
    screen: {
        const want = Quickshell.env("RIZZ_MONITOR");
        return Quickshell.screens.find(s => s.name === want) ?? Quickshell.screens[0];
    }
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Overlay + exclusive: above waybar, and every key comes here while open.
    // The namespace is the default one on purpose — the `blur-quickshell` layer
    // rule in hyprland.lua matches it, so the desktop behind the scrim blurs.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell"

    // ── Geometry ─────────────────────────────────────────────────────────────
    readonly property real cardH: Math.round(height * 0.46)
    readonly property real bigW: Math.round(cardH * 16 / 9)
    readonly property real smallW: Math.round(cardH * 0.24)
    // tan(~12°). Every card is the same parallelogram, so neighbours' edges
    // run parallel and the gap between them stays even.
    readonly property real skew: 0.21
    readonly property real lean: skew * cardH / 2   // horizontal offset at top/bottom
    readonly property int moveMs: 320

    // ── State ────────────────────────────────────────────────────────────────
    property var entries: []      // { kind, path, thumb, name }
    property string query: ""
    property string current: ""   // what wallpaper.sh says is set now
    property bool listed: false
    property bool closing: false
    // The index the strip has come to rest on. The full-resolution image and
    // the video preview load only for this one, after the movement stops —
    // holding an arrow key would otherwise start a 4K decode per card passed.
    property int settled: -1

    readonly property var shown: {
        const terms = query.toLowerCase().split(/\s+/).filter(t => t !== "");
        if (terms.length === 0) return entries;
        return entries.filter(e => {
            const n = e.name.toLowerCase();
            return terms.every(t => n.includes(t));
        });
    }
    readonly property var sel: shown[view.currentIndex] ?? null

    function pretty(file) {
        return file.replace(/\.[^.]+$/, "").replace(/[_-]+/g, " ").trim();
    }
    // file:// plus a per-segment encode. A bare "file://" + path breaks on a
    // '#' (read as a fragment) or a '?' in a filename.
    function url(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // Instant, not positionViewAtIndex(): that one lays the strip out with
    // every card at its slice width, and StrictlyEnforceRange then re-picks
    // whichever card ends up in the middle once the current one widens — it
    // opened three cards off the real wallpaper. Setting currentIndex with the
    // animations switched off lets the range logic do the centring itself.
    property bool instant: true
    function jumpToCurrent() {
        if (!listed) return;
        const i = current === "" ? -1 : shown.findIndex(e => e.path === current);
        instant = true;
        view.currentIndex = Math.max(0, i);
        settled = view.currentIndex;
        Qt.callLater(() => { instant = false; });
    }
    function step(n) {
        if (shown.length === 0) return;
        view.currentIndex = (view.currentIndex + n + shown.length) % shown.length;
    }
    function shuffle() {
        if (shown.length < 2) return;
        let i = view.currentIndex;
        while (i === view.currentIndex) i = Math.floor(Math.random() * shown.length);
        view.currentIndex = i;
    }
    function apply(e) {
        if (!e || closing) return;
        // execDetached: wallpaper.sh outlives this process, which quits now.
        // The wave transition plays on the desktop behind the fading strip.
        Quickshell.execDetached({ command: [root.script, "set", e.path] });
        leave();
    }
    function leave() {
        if (closing) return;
        closing = true;
        outro.start();
    }

    // ── Data ─────────────────────────────────────────────────────────────────
    Process {
        command: [root.script, "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 3) continue;
                    out.push({ kind: f[0], path: f[1], thumb: f[2],
                               name: root.pretty(f[1].substring(f[1].lastIndexOf("/") + 1)) });
                }
                root.entries = out;
                root.listed = true;
                root.jumpToCurrent();
            }
        }
    }
    Process {
        command: [root.script, "current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.current = text.trim(); root.jumpToCurrent(); }
        }
    }

    // A new query rebuilds the model and resets the strip to its first match.
    // On the query, not on `shown`: shown also changes when the list first
    // arrives, and resetting then would undo jumpToCurrent().
    onQueryChanged: Qt.callLater(() => { view.currentIndex = 0; settled = 0; })

    Timer {
        id: settle
        interval: root.moveMs
        onTriggered: root.settled = view.currentIndex
    }

    // ── Palette ──────────────────────────────────────────────────────────────
    // The dashboard's file, one directory up. watchChanges stays on: it is
    // cheap, and a wallpaper picked from here re-themes the strip while it
    // fades out instead of on the next open.
    FileView {
        id: pal
        path: Quickshell.shellPath("../generated-colors.json")
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property string base: "#1e1e2e"
            property string mantle: "#181825"
            property string crust: "#11111b"
            property string surface0: "#313244"
            property string surface1: "#45475a"
            property string overlay0: "#6c7086"
            property string subtext0: "#a6adc8"
            property string text: "#cdd6f4"
            property string mauve: "#cba6f7"
        }
    }

    Component.onCompleted: {
        // Same as the dashboard and the lock: watchFiles would reload this
        // config whenever a file in its directory changed.
        Quickshell.watchFiles = false;
        intro.start();
    }

    // ── Painting ─────────────────────────────────────────────────────────────
    // Scrim + click-outside-to-close. 0.55, well above the blur rule's
    // ignore_alpha (0.0), so the whole backdrop is blurred, not just the cards.
    Rectangle {
        anchors.fill: parent
        color: pal.adapter.crust
        opacity: stage.opacity * 0.55
        MouseArea { anchors.fill: parent; onClicked: root.leave() }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        property real rise: 40

        ParallelAnimation {
            id: intro
            NumberAnimation { target: stage; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "rise"; to: 0; duration: 380; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            id: outro
            ParallelAnimation {
                NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                NumberAnimation { target: stage; property: "rise"; to: 30; duration: 200; easing.type: Easing.InCubic }
            }
            ScriptAction { script: Qt.quit() }
        }

        ListView {
            id: view
            y: (root.height - height) / 2 - 40 + stage.rise
            width: parent.width
            height: root.cardH
            orientation: ListView.Horizontal
            model: root.shown
            spacing: 14
            // The current card is pinned to the middle by computing contentX
            // directly, NOT by highlightRangeMode. The range logic picks its
            // target from the item positions at the moment the move starts,
            // while the old card is still shrinking and the new one growing,
            // so it landed a card-width off centre. Here the target is exact:
            // every card before the current one is a slice once the widths
            // settle, so the current card's left edge is index·(slice+gap).
            interactive: false            // the wheel and keys drive it
            highlightRangeMode: ListView.NoHighlightRange
            highlightFollowsCurrentItem: false
            keyNavigationEnabled: false   // keys belong to the search box
            cacheBuffer: root.bigW * 2
            readonly property real target:
                currentIndex * (root.smallW + spacing) - (width - root.bigW) / 2
            onCurrentIndexChanged: { settle.restart(); place(); }
            onTargetChanged: place()
            function place() {
                slide.stop();
                if (root.instant) { contentX = target; return; }
                slide.to = target;
                slide.start();
            }
            NumberAnimation {
                id: slide
                target: view
                property: "contentX"
                duration: root.moveMs
                easing.type: Easing.OutCubic   // same curve as the width, so they track
            }

            // Every delegate is a slice-wide SLOT, and the current card simply
            // draws wider than its slot; the cards after it are pushed right
            // by `face.x` instead of by the layout. That keeps the ListView's
            // own geometry uniform. With real widths that varied, any jump
            // past the created delegates (Ctrl+R) made ListView place the
            // landing card from its *average* item size, which counted the
            // big card in — so the strip landed off centre, sometimes with
            // the big card on the left, and the formula above could not know.
            // Uniform slots make that estimate exact.
            //
            // The shift and the width use the same duration and curve, so on
            // a one-card step the gap between a shrinking card and its growing
            // neighbour stays exactly `spacing` the whole way.
            delegate: Item {
                id: card
                required property var modelData
                required property int index
                // From the index, not ListView.isCurrentItem: that attached
                // property belongs to whichever instance ListView created as
                // currentItem, and a far jump can briefly make that a
                // different object from the delegate on screen.
                readonly property bool isCur: index === view.currentIndex
                readonly property bool isVideo: modelData.kind === "video"
                readonly property bool live: isCur && index === root.settled

                width: root.smallW
                height: root.cardH
                z: isCur ? 2 : 1

                Item {
                    id: face
                    x: card.index > view.currentIndex ? root.bigW - root.smallW : 0
                    width: card.isCur ? root.bigW : root.smallW
                    height: root.cardH
                    Behavior on x {
                        enabled: !root.instant
                        NumberAnimation { duration: root.moveMs; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        enabled: !root.instant
                        NumberAnimation { duration: root.moveMs; easing.type: Easing.OutCubic }
                    }

                    // The parallelogram. clip on a sheared item clips to the sheared
                    // shape (Qt falls back from scissor to stencil for any
                    // non-axis-aligned transform), which is the whole trick: no
                    // masks, no shaders, no QtQuick.Effects.
                    Item {
                        id: frame
                        anchors.fill: parent
                        clip: true
                        // x' = x - skew·(y - h/2): top leans right, bottom left.
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -root.skew, 0, root.lean,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        // Counter-sheared so the picture stays upright. Widened by
                        // `lean` on each side to cover the parallelogram's corners.
                        Item {
                            x: -root.lean
                            width: face.width + 2 * root.lean
                            height: card.height
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, root.skew, 0, -root.lean,
                                                     0, 1, 0, 0,
                                                     0, 0, 1, 0,
                                                     0, 0, 0, 1)
                            }

                            Rectangle { anchors.fill: parent; color: pal.adapter.surface0 }

                            Image {
                                id: thumb
                                anchors.fill: parent
                                source: root.url(card.modelData.thumb)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                            // The original, for the middle card only, once the
                            // strip is still. Fades in over the thumbnail.
                            Image {
                                id: full
                                anchors.fill: parent
                                source: card.live && !card.isVideo ? root.url(card.modelData.path) : ""
                                sourceSize.width: Math.round(root.bigW * 1.5)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                            Loader {
                                anchors.fill: parent
                                active: card.live && card.isVideo
                                sourceComponent: Video {
                                    source: root.url(card.modelData.path)
                                    autoPlay: true
                                    muted: true
                                    loops: MediaPlayer.Infinite
                                    fillMode: VideoOutput.PreserveAspectCrop
                                }
                            }
                            // Slices are dimmed rather than faded, so the blurred
                            // desktop does not show through them.
                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: card.isCur ? 0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: root.moveMs } }
                            }
                            // Video marker on every card, centred on the visible
                            // part: this item is symmetric about the card's centre.
                            Text {
                                visible: card.isVideo && !card.live
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                text: "\u{F03D}"   // nf-fa-video_camera, checked rendered
                                font.family: root.nf
                                font.pixelSize: 20
                                color: pal.adapter.text
                                style: Text.Outline
                                styleColor: "#80000000"
                            }
                        }

                        // Accent edge on the middle card. In the sheared frame, so
                        // it follows the slant.
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 3
                            border.color: pal.adapter.mauve
                            opacity: card.isCur ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: root.moveMs } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.isCur ? root.apply(card.modelData)
                                              : (view.currentIndex = card.index)
                    }
                }
            }
        }

        // Wheel and touchpad: one card per notch. The accumulator is what keeps
        // a touchpad (dozens of small deltas per swipe) from racing to the end.
        MouseArea {
            anchors.fill: view
            acceptedButtons: Qt.NoButton
            property real acc: 0
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
                acc += d;
                while (acc >= 120) { root.step(-1); acc -= 120; }
                while (acc <= -120) { root.step(1); acc += 120; }
            }
        }

        // ── Caption ──────────────────────────────────────────────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: view.y + view.height + 28
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.sel ? root.sel.name
                     : root.listed ? "sin resultados" : "cargando…"
                color: pal.adapter.text
                font.family: root.nf
                font.pixelSize: 24
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.sel !== null
                text: root.sel
                    ? (root.sel.kind === "video" ? "\u{F03D}  video" : "\u{F03E}  imagen")
                      + "   ·   " + (view.currentIndex + 1) + " / " + root.shown.length
                      + (root.sel.path === root.current ? "   ·   actual" : "")
                    : ""
                color: pal.adapter.subtext0
                font.family: root.nf
                font.pixelSize: 14
            }
        }

        // ── Search ───────────────────────────────────────────────────────────
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 64 - stage.rise
            width: 460
            height: 44
            radius: height / 2
            color: Qt.alpha(pal.adapter.mantle, 0.85)
            border.width: 1
            border.color: search.text !== "" ? pal.adapter.mauve : pal.adapter.surface1

            Text {
                id: lens
                anchors.verticalCenter: parent.verticalCenter
                x: 18
                text: "\u{F002}"   // nf-fa-search, checked rendered
                font.family: root.nf
                font.pixelSize: 16
                color: pal.adapter.overlay0
            }
            TextInput {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: lens.right
                anchors.leftMargin: 12
                anchors.right: shuffleBtn.left
                anchors.rightMargin: 8
                color: pal.adapter.text
                selectionColor: pal.adapter.mauve
                font.family: root.nf
                font.pixelSize: 16
                clip: true
                focus: true
                onTextChanged: root.query = text

                Text {
                    visible: search.text === ""
                    text: "buscar…"
                    color: pal.adapter.overlay0
                    font: search.font
                }

                // Navigation only. No `else`: everything not accepted here
                // falls through to the TextInput's own editing — the dashboard
                // learned that the hard way (a catch-all replaced the query).
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (event.key === Qt.Key_Escape) {
                        if (search.text !== "") search.text = "";
                        else root.leave();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.apply(root.sel);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up
                               || (ctrl && event.key === Qt.Key_H)) {
                        root.step(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down
                               || (ctrl && event.key === Qt.Key_L)) {
                        root.step(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        root.step(-8);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        root.step(8);
                        event.accepted = true;
                    } else if (ctrl && event.key === Qt.Key_R) {
                        root.shuffle();
                        event.accepted = true;
                    }
                }
            }
            Text {
                id: shuffleBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 18
                text: "\u{F074}"   // nf-fa-random, checked rendered
                font.family: root.nf
                font.pixelSize: 16
                color: shuffleArea.containsMouse ? pal.adapter.mauve : pal.adapter.overlay0
                MouseArea {
                    id: shuffleArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shuffle()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: pill.bottom
            anchors.topMargin: 10
            text: "←/→ navegar   ·   Enter aplicar   ·   Ctrl+R aleatorio   ·   Esc cerrar"
            color: pal.adapter.overlay0
            font.family: root.nf
            font.pixelSize: 12
        }
    }
}
