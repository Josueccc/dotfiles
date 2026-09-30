-- hyprland.lua
-- https://wiki.hypr.land/Configuring/Start/


------------------
---- MONITORS ----
------------------

-- Fallback for any output that is not one of the two below (a projector, a
-- second external): preferred mode, Hyprland-derived position, 1.25 scale.
-- It is listed FIRST on purpose — the more specific rules that follow override
-- it, and the order is what makes that true.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1.25",
})

-- The Samsung Odyssey G5 is the main screen while it is plugged in. Pinned to
-- 0x0 so it is always the left-hand output no matter what else shows up, which
-- is what "on the left" has to mean once the layout can change under you.
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",   -- 2560x1440@59.95
    position = "0x0",
    scale    = "1.25",
})

-- The laptop panel gets an EXPLICIT position, never `auto`: 2048x0 to the right
-- of the Samsung (2560 at 1.25 scale) while it is plugged in, 0x0 when it is
-- the only screen. place_panel() below switches between the two on every
-- hotplug. Starting value: whatever the live output set says right now (on
-- a reload), or the undocked 0x0 at first start, which place_panel fixes up
-- from `hyprland.start` once the outputs exist.
local function panel_position()
    return hl.get_monitor("HDMI-A-1") and "2048x0" or "0x0"
end

hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",   -- 1920x1080@120
    position = panel_position(),
    scale    = "1.25",
})

-- "Main screen" also means where focus lands. The active workspace follows the
-- focused monitor, so without this a boot with both outputs up drops you on the
-- laptop panel and the first window you open is on the wrong screen.
--
-- The `get_monitor` guard is the honest part: focusing an output that is not
-- there logs "monitor not found" and leaves focus untouched, which is the
-- behaviour we want on unplug anyway, but a warning on every lid open is noise.
-- With the cable out this returns without dispatching and focus stays on eDP-1,
-- which is then the only monitor there is.
local function focus_primary()
    if hl.get_monitor("HDMI-A-1") then
        hl.dispatch(hl.dsp.focus({ monitor = "HDMI-A-1" }))
    end
end

-- Why not `auto`: it moves the panel, but NOT the layer surfaces on it.
-- Unplugging the Samsung put eDP-1 at 0x0 while waybar and the awww wallpaper
-- stayed at x=2048 (`hyprctl layers`), i.e. off-screen: a bare panel, no bar,
-- no wallpaper, both processes alive. Replug and resume did the reverse (panel
-- at 2048, its layers at 0). Every move `auto` makes on its own is one of
-- those. A rule whose *value* changes forces a real reconfigure, and that DOES
-- re-arrange the layers, while re-applying an identical rule is a no-op. So the
-- panel only ever moves because place_panel changed its rule.
--
-- Deferred because the handler can run while the output set is still
-- settling. `type` is REQUIRED on hl.timer: without it the call returns nil
-- and the callback never fires, with no error.
local function place_panel()
    hl.timer(function()
        local docked = hl.get_monitor("HDMI-A-1") ~= nil
        hl.monitor({
            output   = "eDP-1",
            mode     = "preferred",
            position = docked and "2048x0" or "0x0",
            scale    = "1.25",
        })
        if docked then focus_primary() end
    end, { timeout = 500, type = "oneshot" })
end

-- The other half of the startup call, which lives in the AUTOSTART block below.
-- Hotplug does not re-fire `hyprland.start`, so replugging the cable in needs
-- this: it hands focus back to the Samsung without waiting for a reload.
hl.on("monitor.added", function() focus_primary(); place_panel() end)
hl.on("monitor.removed", function() place_panel() end)


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "thunar"
local browser     = "firefox"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dunst")
    -- Night light. hyprsunset reads hyprsunset.conf and applies the profile
    -- matching the current time, then swaps profiles on its own at their times.
    hl.exec_cmd("pkill -x hyprsunset 2>/dev/null; hyprsunset")
    -- Dashboard overlay (roadmap 3.1). Started with no arguments, which makes
    -- quickshell pick up ~/.config/quickshell/shell.qml as its 'default'
    -- config; that name is what `qs ipc call` has to agree with, and the
    -- --config flag takes a config NAME, not a path, so `qs -c ~/.config/
    -- quickshell` is not a thing that works. pkill first so a stale instance
    -- cannot hold the 'dashboard' IPC target — but note this block runs ONCE,
    -- on hyprland.start. It does not re-fire on `hyprctl reload`, which
    -- apply-theme.sh runs on every wallpaper change: verified by process start
    -- time across an apply run. So a wallpaper change does not restart
    -- quickshell; the palette FileView in shell.qml picks the new colours up
    -- on its own, which is the whole point of it.
    hl.exec_cmd("pkill -x quickshell 2>/dev/null; quickshell")
    -- Put the panel beside the Samsung (or at 0x0 alone) now that the outputs
    -- exist, and start on the main screen rather than whatever Hyprland
    -- happened to pick. See the MONITORS section.
    place_panel()
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- "kde" = KDEPlasmaPlatformTheme6.so from plasma-integration. It reads
-- ~/.config/kdeglobals and hands Qt the [Colors:*] palette, so the
-- Catppuccin scheme there themes every Qt6 app.
--
-- Do NOT switch to hyprqt6engine: the packaged 0.1.0 links against
-- libhyprutils.so.12 and the system has 0.14.2 (soname .13), so its plugin
-- fails to dlopen and Qt falls back to a light palette — white windows, no
-- error anywhere. Verify with: ldd .../platformthemes/libhyprqt6engine.so
--
-- Do NOT switch to qt6ct either, even though its plugin loads cleanly. It
-- themes plain Qt6 apps fine (pavucontrol), but KF6 apps override its
-- palette and stay light — Dolphin rendered #eff0f1 on white under qt6ct
-- and #1e1e2e under kde. Verify by pixel-sampling the window, not by eye.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
-- (a previous "GKT_THEME" typo here set nothing. Left unset on purpose:
-- forcing GTK_THEME=Adwaita:dark would override gtk-theme-name=Breeze and
-- fight the Breeze palette that gtk-3.0/colors.css is written against.)
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.25")
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.25")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Border colors: wallpaper-driven via wallust (~/.config/hypr/generated-colors.lua),
-- Catppuccin blue→mauve gradient as fallback when the file doesn't exist yet.
local border_active   = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 }
local border_inactive = "rgba(595959aa)"

local gen_colors = os.getenv("HOME") .. "/.config/hypr/generated-colors.lua"
local fh = io.open(gen_colors, "r")
if fh then
    fh:close()
    local ok, gen = pcall(dofile, gen_colors)
    if ok and type(gen) == "table" and gen.color4 and gen.color5 then
        local function rgba(hex, alpha) return "rgba(" .. hex:gsub("#", "") .. alpha .. ")" end
        border_active   = { colors = { rgba(gen.color4, "ee"), rgba(gen.color5, "ee") }, angle = 45 }
        border_inactive = rgba(gen.color8 or "#595959", "aa")
    end
end

hl.config({
    general = {
        gaps_in  = 10,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = border_active,
            inactive_border = border_inactive,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding = 12,

        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = "rgba(00000066)",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            ignore_opacity    = true,
            new_optimizations = true,
            xray              = false,
            noise             = 0.02,
            contrast          = 0.9,
            brightness        = 0.8,
            vibrancy          = 0.25,
            popups            = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Bezier curves
hl.curve("wind",   { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05} } })
hl.curve("winIn",  { type = "bezier", points = { {0.1,  1.1},  {0.1, 1.1}  } })
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3},  {0,   1}    } })
hl.curve("liner",  { type = "bezier", points = { {1,    1},    {1,   1}    } })

hl.animation({ leaf = "windows",     enabled = true, speed = 6,  bezier = "wind",  style = "popin 87%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6,  bezier = "winIn", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "winOut", style = "popin 87%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "wind" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
-- Rotating gradient on the active border
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "liner", style = "loop" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "wind" })

-- Blur behind shell layers (bar, launcher, notifications, OSD)
hl.layer_rule({ name = "blur-waybar",        match = { namespace = "waybar" },                      blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "blur-rofi",          match = { namespace = "rofi" },                        blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ name = "blur-swaync-cc",     match = { namespace = "swaync-control-center" },       blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ name = "blur-swaync-notif",  match = { namespace = "swaync-notification-window" },  blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ name = "blur-swayosd",       match = { namespace = "swayosd" },                     blur = true, ignore_alpha = 0.4 })
-- The dashboard overlay (roadmap 3.1) is a FULLSCREEN layer surface, so unlike
-- the rules above this one blurs the whole desktop whenever it is summoned.
-- That is the point — it is the frosted-modal look, and it is why the card
-- itself can stay at 0.93 alpha without terminal text reading through it.
--
-- ignore_alpha = 0 here, not the 0.4 the others use: those windows are small
-- and opaque, so ignoring near-transparent pixels saves work. This surface is
-- transparent everywhere except the card, so a 0.4 threshold would skip exactly
-- the backdrop we want blurred. Cost is one fullscreen 2-pass blur, and only
-- while the overlay is open — see the 1650 perf note in RIZZ-ROADMAP.md.
hl.layer_rule({ name = "blur-quickshell",   match = { namespace = "quickshell" },                  blur = true, ignore_alpha = 0.0 })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us, latam",
        -- Standard US, not "intl," (US international with dead keys). The variant
        -- list is positional and parallel to kb_layout, so the empty first entry
        -- is the US layout's "no variant" and the trailing comma is Latam's.
        -- With "intl," the accented characters are dead keys: it types ñ as
        -- <dead-accent> then n, which is easy to forget you are doing.
        kb_variant   = ",",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
            drag_lock      = true,
        },
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",      hl.dsp.window.close())
-- Logout: hyprshutdown first, because it stops apps cleanly. The fallbacks are
-- the same Lua-hyprctl trap as the layout toggle — `hyprctl dispatch exit` is a
-- parse error there — so the eval form comes first and the classic form stays as
-- the last resort for a stock Hyprland. Single-quoted so the inner double quotes
-- survive. The exit dispatcher itself is the one call here that cannot be tested
-- without ending the session, so it is unproven by design; if hyprshutdown ever
-- goes missing, check this line before assuming the key is dead.
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd('command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl eval "hl.dispatch(hl.dsp.exit())" || hyprctl dispatch exit'))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P",      hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",      hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen())

-- Toggle keyboard layout (US ↔ ES latam). This was
-- `hyprctl dispatch switchxkblayout all next`, which is a hard error on this
-- machine: its hyprctl is the Lua build, so dispatch arguments are parsed as Lua
-- and the key did nothing. See hyprland/scripts/toggle-kb-layout.sh for why that
-- cannot be fixed from a dispatcher call, and why the script also keeps this
-- working on a stock Hyprland.
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-kb-layout.sh"))

-- Focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + h",     hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l",     hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j",     hl.dsp.focus({ direction = "down" }))

-- Move windows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + h",     hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + l",     hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + k",     hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + j",     hl.dsp.window.move({ direction = "down" }))

-- Resize
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.resize({ x = 30, y = 0 }),  { repeating = true })
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.resize({ x = -30, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.resize({ x = 0, y= -30 }), { repeating = true })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.resize({ x = 0, y = 30 }),  { repeating = true })

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Applications
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty -e tmux new-session -A -s main"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("kitty -e yazi"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("kitty -e lazygit"))

-- Wallpaper picker
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.config/waybar/scripts/wallpaper-picker.sh"))

-- Dashboard overlay: calendar, media, system monitor, app launcher.
-- Toggled over IPC rather than by starting/stopping quickshell — launching the
-- shell on every press would put a ~200ms Qt startup in the keypress, and
-- killing it on close would throw away the MPRIS connection.
--
-- `qs` with no config flag is deliberate: the config sits at
-- ~/.config/quickshell/shell.qml, which quickshell registers as 'default'.
-- Do NOT reach for `-c ~/.config/quickshell` — -c/--config takes a config NAME
-- and looks for ~/.config/quickshell/<name>/shell.qml, so it silently finds
-- nothing.
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc call dashboard toggle"))

-- Lock screen (roadmap 3.3). This is the quickshell lock — a real Wayland
-- session lock with a PAM prompt and now-playing — not hyprlock.
--
-- The script, not a bare `quickshell -p ...`, because it has to clear a stale
-- lock process first: a second WlSessionLock cannot lock while one is already
-- engaged, so a leftover process would make this bind silently do nothing.
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/lock.sh"))

-- hyprlock is kept, on its own bind, as the fallback. It is worth being precise
-- about what that buys: ext-session-lock-v1 holds the lock and paints a solid
-- colour if the lock surface dies without an unlock, so hyprlock cannot rescue
-- a quickshell lock that is currently holding the session. It covers the other
-- case — the quickshell lock's UI is broken or never engaged — and it costs
-- nothing to keep, since hyprlock.conf is already tuned (roadmap 1.2).
hl.bind(mainMod .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

-- Night light (manual override on top of the hyprsunset time profiles)
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/nightlight.sh"))

-- Power menu
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/waybar/scripts/powermenu.sh"))

-- Notification center
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"))

-- Screenshot
hl.bind("Print",         hl.dsp.exec_cmd("grimblast copy area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copy screen"))

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"),        { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),  { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),   { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })

-- Logout
hl.bind(mainMod .. " + m", hl.dsp.exec_cmd("hyprshutdown"))

-- Neovim
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("kitty -e nvim"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Workspaces 1-5 live on the Samsung, 6-10 on the laptop panel. Both ranges are
-- needed: an unassigned workspace does not default to "the other monitor", it
-- goes to whichever monitor has focus, and focus starts on the Samsung (see
-- focus_primary in the MONITORS section). With only the 1-5 half written, all
-- ten workspaces pile up on the external display.
--
-- One rule per workspace, never a range — this is the part that is easy to get
-- wrong and it fails *silently*, with no config error and no warning. Both of
-- these parse cleanly and do nothing:
--
--   hl.workspace_rule({ workspace = "1-5",  monitor = "HDMI-A-1" })
--   hl.workspace_rule({ workspace = "r[1-5]", monitor = "HDMI-A-1" })
--
-- Verified by creating fresh workspaces and reading back `hyprctl workspaces`:
-- with a range bound to HDMI-A-1, a brand new ws 25 still came up on eDP-1, and
-- so did one under `r[60-69]`. The wiki says why — workspace selectors "can
-- only match existing workspaces", so a range is evaluated against the
-- workspaces that already exist and never binds a workspace being created. A bare
-- numeric id is the only form that binds at creation: ws 40 with a "40" rule
-- came up on HDMI-A-1 and ws 41 on eDP-1, both first time.
--
-- Corollary worth keeping: the binding is applied when a workspace is CREATED
-- and is never revisited. A workspace that already exists on the wrong monitor
-- stays there, not on reload and not when a window is moved onto it, so this
-- config only binds workspaces that do not exist yet. There is no destroy
-- dispatcher in this build to clear the old ones; a fresh login is the fix.
--
-- The `default` flag is the startup half: it is what decides which workspace each
-- monitor comes up on, which is ws 1 on the Samsung and ws 6 on the panel.
-- `default = (i == first)` leaves the field off entirely for the rest, and
-- `nil` in a Lua table literal is just an absent key, not an error.
local function assign_workspaces(first, last, monitor)
    for i = first, last do
        hl.workspace_rule({
            workspace = tostring(i),
            monitor   = monitor,
            default   = (i == first) or nil,
        })
    end
end

assign_workspaces(1,  5,  "HDMI-A-1")
assign_workspaces(6, 10, "eDP-1")

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Popups: float, then size, then center. Three separate rules per popup so the
-- order of the effects is explicit (a floating window has to exist before it can
-- be resized, and has to be sized before it can be centered).
--   popup(name, match, width_fraction, height_fraction)
local function popup(name, match, w, h)
    hl.window_rule({ name = name .. "-float",  match = match, float = true })
    hl.window_rule({ name = name .. "-size",   match = match,
                     size  = { "(monitor_w*" .. w .. ")", "(monitor_h*" .. h .. ")" } })
    hl.window_rule({ name = name .. "-center", match = match, center = true })
end

-- Audio mixer
popup("pavucontrol", { class = "^(pavucontrol)$" }, "0.45", "0.45")
popup("pavucontrol-pulse", { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, "0.45", "0.45")

-- Network connections
popup("nm-connection-editor", { class = "^(nm-connection-editor)$" }, "0.45", "0.45")

-- Bluetooth
popup("blueman-manager", { class = "^(blueman-manager)$" }, "0.40", "0.55")

-- GTK file chooser / portal dialogs
popup("xdg-portal-filechooser", { class = "^(xdg-desktop-portal-gtk)$" }, "0.55", "0.65")
popup("thunar-filechooser", { class = "^(thunar)$", title = "^(Open|Select|Save|Choose|New Folder|File Upload)" }, "0.55", "0.65")

-- Thunar archive dialogs (Ark / xarchiver / engrampa share the same shape)
popup("archive-dialog", { title = "^(Compress Files|Extract Files|Create Archive|Archive|Extract)" }, "0.45", "0.55")

-- Screenshot / annotation UIs
popup("satty",  { class = "^(satty)$" }, "0.70", "0.75")
popup("swappy", { class = "^(swappy)$" }, "0.70", "0.75")

-- Polkit authentication popups — pinned so they can't end up behind a window
hl.window_rule({
    name  = "pin-polkit",
    match = { class = ".*-authentication-agent-1$" },
    pin   = true,
    float = true,
    center = true,
    size  = { "(monitor_w*0.40)", "(monitor_h*0.45)" },
})

-- Picture-in-picture — floated and pinned across workspaces
hl.window_rule({
    name  = "float-pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
})

hl.window_rule({
    name  = "pin-pip",
    match = { title = "^(Picture-in-Picture)$" },
    pin   = true,
})
