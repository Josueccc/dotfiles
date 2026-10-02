// Main.qml — the rizz SDDM theme (roadmap 5.4).
//
// The login screen, built as the twin of quickshell/lock: same blurred
// wallpaper, same scrim and vignette, same 110px clock and password pill, same
// palette names. Logging in and unlocking should feel like the same door.
//
// It follows the wallpaper without SDDM ever reading $HOME. The greeter runs as
// the `sddm` user, which cannot see into a 700 home directory, so
// wallust/apply-theme.sh copies the wallpaper and the palette into
// /var/lib/rizz-sddm/ (owned by the user, created by install-sddm-theme.sh),
// and theme.conf.user in this directory is a symlink to the palette there.
// Everything that crosses that boundary is DATA — one image and key=value
// colours — never QML, so a process running as the user cannot change what
// this screen does, only what colour it is.
//
// Test without logging out:
//   sddm-greeter-qt6 --test-mode --theme ~/.dotfiles/sddm/rizz
// In test mode a login attempt fails harmlessly; nothing is authenticated.
//
// Same rules as the quickshell files: no QtQuick.Controls (it would bring a
// style that ignores the palette), and Nerd Font glyphs written as escapes.

import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.base

    readonly property string nf: "JetBrainsMono Nerd Font"

    // ── Palette ─────────────────────────────────────────────────────────────
    // `config` is theme.conf overlaid with theme.conf.user. Every value is a
    // string, which QML coerces to a colour on assignment.
    readonly property color cText: config.text
    readonly property color cSub: config.subtext0
    readonly property color cBlue: config.blue
    // Fixed, NOT from the palette. wallust's color1/color3 are only "red" and
    // "yellow" by position: under deer-forest color1 is #4A4753, a grey-purple,
    // so a failed login would be outlined in grey. Same rule as the tmux
    // statusline (CLAUDE.md): a warning that does not look like one is worse
    // than one that does not match the wallpaper.
    readonly property color cRed: "#f38ba8"
    readonly property color cYellow: "#f9e2af"
    readonly property color cBase: config.base
    readonly property color cCrust: config.crust
    readonly property color cSurface: config.surface1

    // ── State ───────────────────────────────────────────────────────────────
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string message: ""
    property bool failed: false
    property bool busy: false

    // Model roles are only reachable through a delegate, so a hidden Repeater
    // mirrors them into plain arrays the rest of the file can index.
    property var userNames: []
    property var userLabels: []
    property var sessionNames: []
    Repeater {
        model: userModel
        Item {
            required property int index
            required property string name
            required property string realName
            Component.onCompleted: {
                const n = root.userNames.slice(); n[index] = name; root.userNames = n;
                const l = root.userLabels.slice(); l[index] = realName || name; root.userLabels = l;
            }
        }
    }
    Repeater {
        model: sessionModel
        Item {
            required property int index
            required property string name
            Component.onCompleted: {
                const s = root.sessionNames.slice(); s[index] = name; root.sessionNames = s;
            }
        }
    }

    function cycleUser(step) {
        if (userModel.count < 2) return;
        userIndex = (userIndex + step + userModel.count) % userModel.count;
        pass.text = "";
        message = ""; failed = false;
    }
    function cycleSession() {
        if (sessionModel.count < 2) return;
        sessionIndex = (sessionIndex + 1) % sessionModel.count;
    }
    function login() {
        if (busy || pass.text === "") return;
        busy = true;
        message = "";
        sddm.login(userNames[userIndex] || "", pass.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.failed = true;
            root.message = "Login failed";
            pass.text = "";
            pass.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.busy = false;
            root.failed = false;
        }
    }

    // ── Background ──────────────────────────────────────────────────────────
    // A real Gaussian over a half-res decode, overscanned by the blur radius so
    // the edges do not darken — exactly the lock's recipe, see
    // quickshell/lock/shell.qml for why it is not a tiny-decode stretch.
    readonly property bool bgReady: bg.status === Image.Ready
    Image {
        id: bg
        anchors.fill: parent
        anchors.margins: -blur.blurMax
        visible: false
        source: config.background ? "file://" + config.background : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        sourceSize.width: 1280
    }
    MultiEffect {
        id: blur
        anchors.fill: bg
        source: bg
        visible: root.bgReady
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: parseInt(config.blurMax) || 64
        blurMultiplier: 0
    }
    Rectangle {
        anchors.fill: parent
        visible: root.bgReady
        color: Qt.alpha("#000000", 0.55)
    }
    Rectangle {
        anchors.fill: parent
        visible: root.bgReady
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha("#000000", 0.28) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha("#000000", 0.28) }
        }
    }

    // ── Clock ───────────────────────────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: root.now = new Date()
    }

    component ShadowedText: Text {
        property color shadowColor: Qt.alpha("#000000", 0.75)
        Text {
            z: -1
            x: 2; y: 2
            text: parent.text
            font: parent.font
            color: parent.shadowColor
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 520)
        spacing: 10

        ShadowedText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.cText
            shadowColor: Qt.alpha(root.cCrust, 0.8)
            font.family: root.nf
            font.pixelSize: 110
            font.weight: Font.Bold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: Qt.alpha(root.cText, 0.73)
            font.family: root.nf
            font.pixelSize: 22
        }

        Item { width: 1; height: 36 }

        // ── User ────────────────────────────────────────────────────────────
        // One user here, so the arrows only appear when there is a choice.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Text {
                visible: userModel.count > 1
                text: "\uf053"                       // chevron-left
                color: root.cSub
                font.family: root.nf; font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.cycleUser(-1) }
            }
            Text {
                text: "\u{F0004}  " + (root.userLabels[root.userIndex] || "")   // account
                color: Qt.alpha(root.cText, 0.85)
                font.family: root.nf
                font.pixelSize: 18
            }
            Text {
                visible: userModel.count > 1
                text: "\uf054"                       // chevron-right
                color: root.cSub
                font.family: root.nf; font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.cycleUser(1) }
            }
        }

        Item { width: 1; height: 8 }

        // ── Password ────────────────────────────────────────────────────────
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320; height: 52

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(root.cBase, 0.8)
                border.width: 2
                border.color: root.failed ? root.cRed : root.cBlue
                Behavior on border.color { ColorAnimation { duration: 140 } }
            }

            TextInput {
                id: pass
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: root.cText
                font.family: root.nf
                font.pixelSize: 15
                echoMode: TextInput.Password
                passwordCharacter: "\u25cf"
                font.letterSpacing: 3       // the dots touch without it
                enabled: !root.busy
                clip: true
                focus: true

                // Navigation only; everything else falls through unaccepted so
                // the field does its own editing (the dashboard's catch-all
                // `else` trap).
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.login();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        pass.text = "";
                        root.message = ""; root.failed = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        root.cycleUser(event.key === Qt.Key_Up ? -1 : 1);
                        event.accepted = true;
                    }
                }
                onTextEdited: if (root.failed) { root.failed = false; root.message = "" }
            }

            Text {
                anchors.centerIn: parent
                visible: pass.text === "" && !root.busy
                text: "Password..."
                color: root.cSub
                font.family: root.nf
                font.pixelSize: 15
                font.italic: true
            }
        }

        // Failure, or caps lock — the one warning worth having on a login
        // screen, because it is the usual reason for the failure above it.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.message !== "" ? root.message
                : keyboard.capsLock ? "\u{F0632}  Caps Lock is on" : ""
            color: root.message !== "" ? root.cRed : root.cYellow
            font.family: root.nf
            font.pixelSize: 13
            height: 18
        }

        Item { width: 1; height: 4 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "enter  log in        esc  clear"
            color: Qt.alpha(root.cSub, 0.5)
            font.family: root.nf
            font.pixelSize: 13
            font.italic: true
        }
    }

    // ── Session (bottom left) and power (bottom right) ──────────────────────
    // The session is a click-to-cycle label, not a dropdown: one click per
    // session beats importing a ComboBox and its style.
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        text: "\uf108  " + (root.sessionNames[root.sessionIndex] || "")    // desktop
        color: sessArea.containsMouse ? root.cText : root.cSub
        font.family: root.nf
        font.pixelSize: 14
        MouseArea {
            id: sessArea
            anchors.fill: parent; anchors.margins: -8
            hoverEnabled: true
            onClicked: root.cycleSession()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 26
        Repeater {
            model: [
                { glyph: "\u{F04B2}", label: "Suspend",  can: "canSuspend",  fn: "suspend" },
                { glyph: "\u{F0709}", label: "Reboot",   can: "canReboot",   fn: "reboot" },
                { glyph: "\u{F0425}", label: "Shut down", can: "canPowerOff", fn: "powerOff" }
            ]
            Text {
                required property var modelData
                visible: sddm[modelData.can]
                text: modelData.glyph
                color: area.containsMouse ? root.cText : root.cSub
                font.family: root.nf
                font.pixelSize: 20
                MouseArea {
                    id: area
                    anchors.fill: parent; anchors.margins: -8
                    hoverEnabled: true
                    onClicked: sddm[modelData.fn]()
                }
            }
        }
    }

    Component.onCompleted: pass.forceActiveFocus()
}
