// LockUi.qml — the visual layer of the roadmap 3.3 lock screen.
//
// Split out from shell.qml for one reason: the lock screen is security
// critical, and it has to be *verifiable*. ext-session-lock-v1 has the
// property that while a session is locked, no client can screenshot the
// output — so `grim` cannot photograph this UI while it is doing its job.
// Rendering the same component in an ordinary PanelWindow can, which is how
// the layout below was actually checked. See the "Verifying the lock screen"
// section of quickshell/README.md.
//
// Deliberately NOT a sub-component of the dashboard's shell.qml. That file's
// "everything in one file" rule is about a single PanelWindow's ids, and does
// not apply across two processes that share nothing but the palette.
//
// Signals rather than a passed-in PamContext: the two files are loaded
// through a Component, so they share no ids, and handing the auth object
// across that boundary would be the only place in this setup where one file
// reaches into another's internals.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: ui

    // Set by the shell. Sourced from $USER at runtime, not hardcoded, so this
    // file is not wrong on another machine.
    property string userName: ""

    readonly property string nf: "JetBrainsMono Nerd Font"

    // The text travels WITH the signal, on purpose.
    //
    // The root cannot reach in here. `ui` is declared inside the lock surface,
    // and the surface only exists once the lock is engaged, so the id is not in
    // scope from the ShellRoot — every `ui.something()` call from the root
    // throws "ReferenceError: ui is not defined". The first version did exactly
    // that and it broke the lock in two places at once: `ui.focusInput()`
    // failed, so the password field never took focus and typing went nowhere,
    // and `ui.inputText()` returned undefined, so `pam.respond(undefined)`
    // killed the PAM subprocess and Enter did nothing. The symptom was a lock
    // screen that looked completely normal and could not be unlocked.
    //
    // So: data flows root -> child by property binding (that direction is
    // fine), and child -> root by signal. Nothing reaches in.
    signal submitRequested(string response)
    signal cancelRequested()

    // ── Palette ──────────────────────────────────────────────────────────────
    // The dashboard's palette, one directory up. Same wallust template
    // (colors-quickshell.json), same field names, so the two cannot drift.
    //
    // This is the one thing hyprlock could never do: hyprlock cannot include
    // files, so hyprlock.conf hardcoded Catppuccin and the lock screen was the
    // only surface in the pipeline that ignored the wallpaper. Its comment said
    // so. That limitation is gone with it.
    FileView {
        id: pal
        path: Quickshell.shellPath("../generated-colors.json")
        watchChanges: false   // see shell.qml: the lock must never reload
        blockLoading: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            // Catppuccin Mocha seeds, identical to the dashboard's, so a
            // missing generated file still gives a readable screen rather than
            // an unthemed one.
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

    // ── Clock ────────────────────────────────────────────────────────────────
    // Second precision, unlike the dashboard's Minutes. A lock screen is
    // usually the first thing looked at and often the only thing on screen,
    // so it is worth the one extra wakeup a second — and the seconds are what
    // make it obvious at a glance that the screen is live and not a still.
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ── Media ────────────────────────────────────────────────────────────────
    // Same rule as the dashboard: MPRIS properties change on the player's own
    // schedule and nothing here reads them reactively, so a timer drives
    // re-evaluation.
    property int tick: 0
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: ui.tick = ui.tick + 1
    }

    readonly property var mpris: {
        const _ = ui.tick;
        const all = Mpris.players.values;
        for (const p of all) if (p.isPlaying) return p;
        return all.length > 0 ? all[0] : null;
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    // A drop shadow, drawn rather than composited. hyprlock 1.2 had
    // shadow_passes/shadow_size on every label and the roadmap calls the
    // "110px clock with drop shadow" out as tuned, so the shadow is part of the
    // look — but it cannot be a QtQuick.Effects one: in Qt 6.11 that module
    // exports only MultiEffect and RectangularShadow, and DropShadow is gone
    // (`DropShadow is not a type`). Binding the lock screen to an effect that
    // a Qt point release removed is not worth a cosmetic shadow, and this
    // version does the same job with one extra Text and no module at all.
    component ShadowedText: Text {
        property color shadowColor: Qt.alpha("#000000", 0.75)
        property int shadowOffset: 2

        // A child item paints AFTER its parent's own content, so without an
        // explicit z this "shadow" lands on top and the text reads as a smear.
        // Same sibling-order-is-paint-order trap as the dashboard's today-pill.
        Text {
            z: -1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: parent.shadowOffset
            anchors.topMargin: parent.shadowOffset
            text: parent.text
            font: parent.font
            color: parent.shadowColor
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 520)
        spacing: 10

        // U+F09C, and NOT the U+F0233 that hyprlock 1.2 used and that the
        // roadmap records as "the lock".
        //
        // In JetBrainsMono Nerd Font, U+F0233 is a *filter* glyph — a funnel
        // with a bar above it. It reads as a martini glass, and on a lock screen
        // that is worse than no glyph. U+F0233 is presumably correct for whatever
        // font hyprlock actually resolved (pango, which can fall back per-glyph;
        // Qt resolves the family as given), or 1.2's check was cursory. Either
        // way the 1.2 note is wrong for the font this file pins, so it is
        // corrected here rather than copied.
        //
        // U+F09C verified by rendering a labelled sheet of candidates and
        // looking at it — a closed padlock with a shackle. Codepoint names are
        // not evidence; the sheet is.
        ShadowedText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            color: pal.adapter.blue
            shadowColor: Qt.alpha(pal.adapter.crust, 0.8)
            font.family: ui.nf
            font.pixelSize: 22
        }

        // 110px, as tuned in 1.2 and verified there.
        ShadowedText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: pal.adapter.text
            shadowColor: Qt.alpha(pal.adapter.crust, 0.8)
            font.family: ui.nf
            font.pixelSize: 110
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Qt.alpha(pal.adapter.text, 0.73)   // 0xbb in 1.2
            font.family: ui.nf
            font.pixelSize: 22
        }

        Item { width: 1; height: 14 }

        // ── Now playing ───────────────────────────────────────────────────
        // The 5.3 half. Only shown when there is a player at all: a card
        // reading "Nothing playing" on every lock where music is off is just
        // furniture, and the point is the album art when there is one.
        Rectangle {
            id: npCard
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ui.mpris !== null
            width: parent.width
            height: 108
            radius: 14
            color: Qt.alpha(pal.adapter.crust, 0.55)
            border.width: 1
            border.color: Qt.alpha(pal.adapter.surface1, 0.6)

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                // Art, as in the dashboard: MPRIS art is a URL that is a
                // file:// in practice, and Qt will not fetch http(s) here, so
                // remote art is skipped rather than shown broken.
                Rectangle {
                    width: 84; height: 84
                    radius: 10
                    color: pal.adapter.mantle
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: ui.mpris !== null
                            && ui.mpris.trackArtUrl.indexOf("file://") === 0
                        source: visible ? ui.mpris.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 240
                    }

                    Text {
                        anchors.centerIn: parent
                        // Placeholder when there is a player but no usable art
                        // URL. MPRIS art is a file:// path in practice, so this
                        // is the common case, not an edge case.
                        visible: ui.mpris !== null
                            && ui.mpris.trackArtUrl.indexOf("file://") !== 0
                        text: "󰀚"
                        color: pal.adapter.overlay0
                        font.family: ui.nf
                        font.pixelSize: 22
                    }
                }

                Column {
                    width: parent.width - 84 - 14 - 36
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: ui.mpris === null ? "" : (ui.mpris.trackTitle || "Unknown Title")
                        color: pal.adapter.text
                        font.family: ui.nf
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: ui.mpris === null ? "" : (ui.mpris.trackArtist || "Unknown Artist")
                        color: pal.adapter.subtext0
                        font.family: ui.nf
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Item { width: 1; height: 4 }

                    Row {
                        spacing: 14
                        Repeater {
                            model: [
                                { glyph: "", fn: "previous", can: "canGoPrevious" },
                                { glyph: "", fn: "togglePlaying", can: "canTogglePlaying" },
                                { glyph: "", fn: "next", can: "canGoNext" }
                            ]
                            Text {
                                required property var modelData
                                text: modelData.glyph
                                // Null-guarded, not just capability-gated. The
                                // card is hidden when there is no player, but
                                // `visible: false` does not stop a binding from
                                // evaluating, so an unguarded `ui.mpris[can]`
                                // throws "Cannot read property 'canGoNext' of
                                // null" once per player-teardown on every lock
                                // where nothing is playing. Same shape as the
                                // `holds[0]` bug in the dashboard.
                                color: ui.mpris !== null && ui.mpris[modelData.can]
                                    ? pal.adapter.text : pal.adapter.overlay0
                                font.family: ui.nf
                                font.pixelSize: 15
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: {
                                        if (ui.mpris === null) return;
                                        if (!ui.mpris[modelData.can]) return;
                                        ui.mpris[modelData.fn]();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        // U+F0004, from 1.2's correction.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ui.userName === "" ? "" : "󰀄  " + ui.userName
            color: Qt.alpha(pal.adapter.text, 0.67)   // 0xaa in 1.2
            font.family: ui.nf
            font.pixelSize: 16
        }

        Item { width: 1; height: 12 }

        // ── Password ──────────────────────────────────────────────────────
        // A pill, like 1.2's input-field, but a real TextInput rather than
        // hyprlock's dot renderer. echoMode Password is the same guarantee
        // hide_input gave: nothing is drawn that is not a dot.
        Item {
            id: passField
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320; height: 52

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(pal.adapter.base, 0.8)
                // 2px outline, as 1.2 had.
                border.width: 2
                border.color: ui.authFailed ? pal.adapter.red : pal.adapter.blue
                Behavior on border.color { ColorAnimation { duration: 140 } }
            }

            TextInput {
                id: pass
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: pal.adapter.text
                font.family: ui.nf
                font.pixelSize: 15
                selectionColor: pal.adapter.blue
                selectedTextColor: pal.adapter.crust
                echoMode: TextInput.Password
                clip: true

                // Navigation only; everything else falls through UNACCEPTED so
                // the field does its own editing. A catch-all `else` assigning
                // event.text replaces the whole input with one character — the
                // dashboard's first polkit prompt had this written down as a
                // trap and it applies identically here.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        // Hand the password over as the signal's argument, not
                        // by asking the root to come and read it.
                        ui.submitRequested(pass.text);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        pass.text = "";
                        ui.cancelRequested();
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: pass.text === "" && !pass.activeFocus
                text: "<i> Password...</i>"
                // Text.richText is not imported; italic is spelled with the
                // markup below instead of a <i> tag, which would render
                // literally in a plain Text.
                color: pal.adapter.subtext0
                font.family: ui.nf
                font.pixelSize: 15
                font.italic: true
            }
        }

        // PAM's own message, and PAM's own error flag. This is where "Authentication
        // failure" lands, so it is coloured by the flag polkit/PAM sets rather
        // than by guessing from the text.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            visible: ui.authMessage !== ""
            text: ui.authMessage
            color: ui.authFailed ? pal.adapter.red : pal.adapter.subtext0
            font.family: ui.nf
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 10 }

        // 1.2 advertised "Super+Shift+M night light" on the lock screen. That
        // bind has no `locked = true`, so it cannot fire while locked — the
        // hint was wrong there too. These are the keys that actually work.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "enter  unlock        esc  clear"
            color: Qt.alpha(pal.adapter.subtext0, 0.5)   // 0x80 in 1.2
            font.family: ui.nf
            font.pixelSize: 13
            font.italic: true
        }
    }

    // ── Auth state, owned by the shell ───────────────────────────────────────
    // Declared here rather than passed in because both the field border and
    // the message text read them, and threading two properties through a
    // Component boundary for that is the machinery the dashboard README
    // complains about.
    property string authMessage: ""
    property bool authFailed: false

    // Self-contained now: focus and reset are the component's own business.
    // The root cannot call either of them (see the signal comment above), and
    // it should not have to — both events are things that happen to *this*
    // component, not things the shell asks it to do.
    //
    // Focus on completion is exactly right rather than a workaround: this
    // component is constructed when the lock engages, so construction IS the
    // moment the field should take the keyboard.
    Component.onCompleted: pass.forceActiveFocus()

    // Clear the field whenever PAM says something new. A failed attempt must
    // not leave the wrong password sitting in a masked field, and PAM's message
    // changes on every attempt — including the first prompt, which is a no-op
    // because the field is already empty.
    onAuthMessageChanged: pass.text = ""

    // Re-take focus after a failed attempt: onAuthCompleted clears and refocuses
    // in the root, and the keyboard must not be left on nothing.
    onAuthFailedChanged: if (authFailed) pass.forceActiveFocus()
}
