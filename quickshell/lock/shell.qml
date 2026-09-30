// shell.qml — the roadmap 3.3 lock screen.
//
// A real Wayland session lock (ext-session-lock-v1) with a PAM password prompt
// and now-playing. Started on demand by a keybind or by hypridle; it exits as
// soon as the session is unlocked.
//
// This is a SEPARATE quickshell config, and therefore a separate process, on
// purpose. The lock screen is the one surface where "it did not load" means
// "the machine is not locked", so it must not share a process — or a QML
// syntax error — with the dashboard overlay. `shell.qml` next door is 900
// lines; none of them should be able to break this.
//
// Run:  qs -p ~/.config/quickshell/lock
// Bind: hyprland.lua runs that command; see the comment there.
//
// Written against quickshell 0.3.1, same as the dashboard. See
// quickshell/README.md for the traps, several of which cost real time here.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    // ── Lock ────────────────────────────────────────────────────────────────
    WlSessionLock {
        id: lock

        // `secure` is the compositor's own confirmation that every screen is
        // covered. It is the only trustworthy "the session really is locked"
        // signal, and it is what the hypridle path has to key off — see below.
        onSecureStateChanged: {
            if (secure) root.startAuth();
        }

        WlSessionLockSurface {
            id: surface
            color: palColor()          // fallback until the capture lands

            // The blurred desktop, as hyprlock's `path = screenshot` did.
            //
            // It is an Image over a PNG that `grim` wrote BEFORE the lock
            // engaged — not a ScreencopyView, and this is the load-bearing
            // design decision in the file.
            //
            // A screencapture taken after the lock engages captures the lock
            // surface itself, and it has to be taken before for the obvious
            // reason. But it CANNOT be taken before, if it lives here: the
            // docs are explicit that WlSessionLock "will create an instance of
            // its surface component for every screen WHEN locked IS SET TO
            // TRUE", so the surface — and anything inside it — does not exist
            // until the lock is on. Putting the capture inside the lock surface
            // is circular. It was written that way first and it cannot work.
            //
            // It does worse than fail. With a ScreencopyView and a
            // ShaderEffectSource inside the surface, engaging the lock tore
            // down the Wayland connection outright:
            //     wl_display#1: error 0: invalid object 52
            //     The Wayland connection experienced a fatal error: Invalid argument
            // which is a protocol-level failure, not a cosmetic one.
            //
            // So: `grim` to a temp file first, then lock, then show the file.
            // The blur is Image.sourceSize — decoding the PNG at 160x90 and
            // letting fillMode magnify it back up. No compositor blur, which is
            // the right call twice over: quickshell's BackgroundEffect only
            // applies to its own layer surfaces and an ext-session-lock surface
            // is a different protocol, and this session already fails the blur
            // control test anyway (rofi renders no blur either).
            Image {
                id: bg
                anchors.fill: parent
                visible: root.bgReady
                source: root.bgReady ? root.bgUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                // Decode small, display large. Qt box-filters the downscale and
                // the GPU bilinear-filters the upscale, which is a blur that
                // cannot fail to apply.
                sourceSize.width: 160
                sourceSize.height: 90
            }

            // The dim. hyprlock used brightness 0.75 / contrast 0.89 as
            // compositor-side grading; this is a flat scrim, which cannot
            // blow out the highlights the way a brightness filter can.
            Rectangle {
                anchors.fill: parent
                visible: root.bgReady
                color: Qt.alpha("#000000", 0.55)
            }

            // A vignette, so the clock keeps its contrast at the edges of a
            // bright wallpaper instead of only in the middle.
            Rectangle {
                anchors.fill: parent
                visible: root.bgReady
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha("#000000", 0.28) }
                    GradientStop { position: 0.5; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha("#000000", 0.28) }
                }
            }

            LockUi {
                id: ui
                anchors.fill: parent
                width: parent.width
                height: parent.height
                userName: Quickshell.env("USER") || ""
                authMessage: root.pamMessage
                authFailed: root.pamFailed
                onSubmitRequested: response => root.submit(response)
                onCancelRequested: root.abortAuth()
            }
        }
    }

    // The lock surface's own background, used until the capture arrives. Read
    // from the same generated file as the UI, so the first frame is already
    // themed rather than flashing Catppuccin over a wallpaper-derived screen.
    readonly property string _palBase: uiPaletteBase()
    function palColor() { return _palBase }

    // ── Palette ──────────────────────────────────────────────────────────────
    // Duplicated from LockUi rather than shared. Two FileViews of the same
    // small JSON is cheaper than inventing a singleton that both files have to
    // import, and the surface needs the colour before LockUi exists.
    FileView {
        id: surfPal
        path: Quickshell.shellPath("../generated-colors.json")
        watchChanges: false
        blockLoading: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property string base: "#1e1e2e"
        }
    }
    function uiPaletteBase() { return surfPal.adapter.base }

    // ── Auth ─────────────────────────────────────────────────────────────────
    PamContext {
        id: pam
        // "login", not "hyprlock". /etc/pam.d/hyprlock is literally
        // `auth include login`, so this is the same auth stack — but the
        // hyprlock file only exists because the hyprlock package is installed,
        // and hyprlock stays installed here as a fallback, so tying the
        // primary lock's auth to a fallback's package is the wrong dependency
        // direction. `login` is from the base pam package and always present.
        config: "login"
        // $USER, not the polkit display name. PAM resolves a login name; the
        // polkit identity's displayName is the GECOS field ("josue" on this
        // machine) and start() fails outright with
        // "specified user was not found" if you pass it.
        user: Quickshell.env("USER") || ""

        onCompleted: root.onAuthCompleted(result)
        onError: root.onAuthError(error)
        onPamMessage: (message, isError, responseRequired, responseVisible) =>
            root.onPamMessage(message, isError, responseRequired, responseVisible)
    }

    property string pamMessage: ""
    property bool pamFailed: false

    // `response` arrives as the signal's argument. The root used to call
    // `ui.inputText()` to fetch it, which threw because `ui` lives inside the
    // lock surface — see the note on the signal in LockUi.qml.
    function submit(response) {
        if (!pam.active) return;
        // Guard the type. An undefined here is not hypothetical: it is exactly
        // what the first version passed, and `pam.respond(undefined)` does not
        // fail loudly — it kills the PAM subprocess, so the field stops
        // responding and the lock cannot be opened. Better to refuse it here.
        if (typeof response !== "string" || response === "") return;
        pam.respond(response);
    }

    // Escape clears the field AND gives up on the attempt. 1.2's hint said
    // "esc clear field", which is only half of it: aborting is what stops a
    // stuck conversation, and it leaves the lock up.
    function abortAuth() {
        if (pam.active) pam.abort();
    }

    function onPamMessage(msg, isError, responseRequired, responseVisible) {
        pamMessage = msg === "Password: " || msg === "Password:" ? "" : msg;
        pamFailed = isError;
    }

    // PamResult: Success, Failed, Error, MaxTries
    //
    // No `ui.*` calls here either. Clearing the field and re-taking focus are
    // both reactions to properties this function sets, so LockUi reacts to them
    // itself (onAuthMessageChanged / onAuthFailedChanged) — see LockUi.qml.
    function onAuthCompleted(result) {
        if (result === 0) {          // Success
            pamMessage = "";
            pamFailed = false;
            release();
        } else {
            // Failed / MaxTries / Error. Stay locked — always. There is no
            // branch here that unlocks on anything but an explicit success.
            pamMessage = result === 3 ? "Too many attempts"
                                      : "Authentication failed";
            pamFailed = true;
        }
    }

    function onAuthError() {
        pamMessage = "Authentication unavailable";
        pamFailed = true;
    }

    // ── Release ──────────────────────────────────────────────────────────────
    // Order matters and is not negotiable: unlock the session FIRST, and only
    // then tear the process down. The ext-session-lock-v1 spec says a
    // conformant compositor that sees the lock surface destroyed without an
    // unlock will hold the lock and paint a solid colour — the session is not
    // exposed, but the machine is unusable until a TTY switch. So `locked =
    // false` has to be acknowledged by the compositor (`secure` going false)
    // before anything here exits.
    function release() {
        lock.locked = false;
    }

    // Started from `secure`, not from a `locked` handler. `locked` is a plain
    // read/write bool with NO change signal — the lock's signals are
    // lockStateChanged, secureStateChanged and surfaceComponentChanged — so
    // `onLocked` does not exist, and writing one is a load-time error rather
    // than a silent no-op.
    //
    // `secure` is the better trigger regardless: it flips only once the
    // compositor has confirmed every screen is actually covered, which is the
    // moment the session is genuinely locked. Reacting to `locked` would start
    // PAM while the screens were still uncovered.
    //
    // A function, not a handler. A bare `onLocked: { ... }` block on the root
    // is a *signal handler* and creates no callable member, so calling
    // `root.onLocked()` from the lock's handler above fails at runtime with
    // "Property 'onLocked' of object ShellRoot_QML_6 is not a function" — while
    // the handler itself looks perfectly correct in the file.
    // No ui.focusInput() here: the lock surface does not exist yet when this
    // runs (it is created *because* the lock engaged, moments later), and the
    // id would not be in scope from the root regardless. LockUi takes focus in
    // its own Component.onCompleted, which is the correct moment anyway.
    function startAuth() {
        if (!pam.start()) onAuthError();
    }

    // Once the compositor reports the lock is down, leave. A lock process that
    // lingers is a process that can be killed at the wrong moment, and this
    // one has no reason to outlive the lock.
    Connections {
        target: lock
        function onSecureStateChanged() {
            if (!lock.secure && !lock.locked) Qt.quit();
        }
    }

    // ── Capture, then lock ───────────────────────────────────────────────────
    // The order is forced by the protocol (see the background comment above):
    // the lock surface cannot exist before the lock engages, so anything
    // captured from inside it would be a capture of the lock screen. grim runs
    // first, to a file, and the lock waits for it.
    //
    // The backstop is the part that matters. If grim is missing, fails, or takes
    // longer than the timeout, the lock engages ANYWAY on a flat themed
    // background. A decorative background must never be able to stop the machine
    // locking: a missing capture costs the blur, and nothing else.
    readonly property string bgPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-lock-bg.png"
    readonly property string bgUrl: "file://" + bgPath
    property bool bgReady: false
    property bool engaged: false

    Process {
        id: grab
        command: ["grim", root.bgPath]
        // Non-zero exit (no grim, no permission, compositor busy) still engages
        // the lock — it just leaves bgReady false and the flat background shows.
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.bgReady = true;
            } else {
                console.warn("quickshell lock: grim exited " + exitCode
                             + ", locking with a flat background");
            }
            root.engage();
        }
    }

    // Backstop for the case where grim never exits at all (hung, or waiting on
    // something). Generous, because firing early costs a flat background and not
    // firing costs an unlocked machine.
    Timer {
        running: !root.engaged
        interval: 2000
        onTriggered: {
            if (!root.engaged) {
                console.warn("quickshell lock: grim did not return after 2000ms, locking anyway");
                root.engage();
            }
        }
    }

    function engage() {
        if (engaged) return;
        engaged = true;
        lock.locked = true;
    }

    Component.onCompleted: {
        // Quickshell.watchFiles defaults to true and reloads the whole config
        // when any file in the config directory changes. In a *locked* config
        // that is not a cosmetic problem: a reload destroys the lock surface,
        // and the compositor then holds the lock with a solid colour and no way
        // to type into it. This is the single most important line in the file.
        //
        // It is the dashboard's trap (quickshell/README.md) wearing a
        // security-critical costume: there it meant the overlay closed on a
        // wallpaper change, here it would brick the session.
        Quickshell.watchFiles = false;

        // Capture, then lock. See the sequencing block above for why this
        // order is forced and why the timeout behind it must never be the thing
        // that decides whether the session locks.
        grab.running = true;
    }
}
