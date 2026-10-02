#!/usr/bin/env bash
# install-sddm-theme.sh — install the rizz SDDM theme (roadmap 5.4).
#
#   sudo ./sddm/install-sddm-theme.sh            install / update, make it current
#   pkexec ~/.dotfiles/sddm/install-sddm-theme.sh  same, with a graphical prompt
#   sudo ./sddm/install-sddm-theme.sh --revert   go back to the previous theme
#
# Needs root, so it is NOT part of install.sh — run it by hand, and re-run it
# after editing anything in sddm/rizz/ (the theme is COPIED, not symlinked: the
# greeter runs as the `sddm` user and cannot read a 700 home directory).
#
# What it sets up:
#   /usr/share/sddm/themes/rizz/            the theme, root-owned
#     theme.conf.user -> /var/lib/rizz-sddm/theme.conf.user
#   /var/lib/rizz-sddm/                     owned by $SUDO_USER, mode 755
#     theme.conf.user, wallpaper.*          written by wallust/apply-theme.sh
#   /etc/sddm.conf.d/zz-rizz.conf           [Theme] Current=rizz
#
# The conf.d file is named zz-* on purpose: SDDM reads that directory in
# alphabetical order and the LAST value wins, and kde_settings.conf (written by
# KDE's System Settings) already sets Current=Ant-Dark-Plasma-6. A 10-* file
# would sort before it and silently lose.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rizz"
THEME=/usr/share/sddm/themes/rizz
DATA=/var/lib/rizz-sddm
CONF=/etc/sddm.conf.d/zz-rizz.conf

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
# The user to hand /var/lib/rizz-sddm to: whoever called sudo, or pkexec. pkexec
# works from places sudo cannot prompt (no terminal) and asks through the
# polkit agent — on this machine, the quickshell prompt.
OWNER="${SUDO_USER:-}"
[ -z "$OWNER" ] && [ -n "${PKEXEC_UID:-}" ] && OWNER=$(id -nu "$PKEXEC_UID")
[ -n "$OWNER" ] && [ "$OWNER" != root ] || { echo "run via sudo or pkexec from your user, not as root" >&2; exit 1; }

if [ "${1:-}" = "--revert" ]; then
    rm -f "$CONF"
    echo "removed $CONF — SDDM falls back to the theme in its other config files"
    echo "(the theme and $DATA are left in place; delete them by hand if wanted)"
    exit 0
fi

[ -f "$SRC/Main.qml" ] || { echo "theme not found at $SRC" >&2; exit 1; }

install -d -m 755 "$THEME"
install -m 644 "$SRC/Main.qml" "$SRC/metadata.desktop" "$SRC/theme.conf" "$THEME/"
ln -sfn "$DATA/theme.conf.user" "$THEME/theme.conf.user"

install -d -m 755 -o "$OWNER" -g "$(id -gn "$OWNER")" "$DATA"

install -d -m 755 /etc/sddm.conf.d
printf '%s\n' '# Written by ~/.dotfiles/sddm/install-sddm-theme.sh' \
              '[Theme]' 'Current=rizz' > "$CONF"

echo "installed: $THEME (current theme: rizz)"

# Fill the data dir now rather than waiting for the next wallpaper change.
# Run as the user, not root, so the files it writes stay theirs.
APPLY="$(dirname "$SRC")/../wallust/apply-theme.sh"
if [ -x "$APPLY" ]; then
    # From /, not root's home: the user cannot enter /root, and find (in the
    # sync) complains when it cannot restore a working directory it cannot read.
    (cd / && sudo -u "$OWNER" -H bash -c "\"$APPLY\" --sddm-only") \
        && echo "synced the current wallpaper and palette into $DATA"
fi
echo "test without logging out:  sddm-greeter-qt6 --test-mode --theme $THEME"
