-- hyprland.lua
-- https://wiki.hypr.land/Configuring/Start/


------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1.25",
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "alacritty"
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
        kb_variant   = "intl,",
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
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P",      hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",      hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen())

-- Toggle keyboard layout (EN intl ↔ ES latam)
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("hyprctl dispatch switchxkblayout all next"))

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

-- Lock screen
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))

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
