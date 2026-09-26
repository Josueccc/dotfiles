# tools

## gtk-preview.py

A throwaway GTK3 window that exercises the palette states a file manager hides
until you click something: a selected row, a link, a checked box, and
normal/suggested/destructive buttons.

```sh
python3 tools/gtk-preview.py
```

Worth using whenever `matugen/templates/breeze.css` changes. Two idle file
managers are nearly indistinguishable — the surfaces only shift a couple of
steps (`#242424` → `#141318`). The accents are where a palette change is
actually visible, and stock Breeze hardcodes a bright blue
(`theme_selected_bg_color_breeze #315bef`) that no wallpaper relates to.

To compare two palettes, run this against each and screenshot the window:

```sh
grim -o "$(pgrep -f gtk-preview.py | head -1)" /tmp/after.png
```

## Why not just screenshot thunar?

Because the difference you are judging lives in selection/hover/link states,
which need a click to appear. Without an input-injection tool on this machine
(no ydotool/wtype/xdotool), the preview is the only way to see them.
