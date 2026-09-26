#!/usr/bin/env bash
# link-profile.sh — point a Firefox profile at the repo's theme files.
#
# Firefox profiles are named with a random hash (e.g. 2z7f38dl.default-release)
# and the name changes if the profile is ever recreated, so the profile path has
# to be resolved from profiles.ini at link time rather than hardcoded.
#
# Creates <profile>/chrome/ and symlinks four files into it:
#   userChrome.css        browser chrome            (tracked)
#   userContent.css       internal/about: pages     (tracked)
#   fallback.css          static Catppuccin palette (tracked)
#   generated-colors.css  wallust palette           (generated, gitignored)
# plus <profile>/user.js for the prefs.
#
# Run with Firefox CLOSED. Rewiring a live profile works, but Firefox caches the
# stylesheets at startup and will not pick them up until it is restarted.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIREFOX_DIR="$REPO/firefox"

# ── Locate the profile root ──────────────────────────────────────────────────
# This machine keeps profiles in ~/.config/mozilla/firefox, NOT the usual
# ~/.mozilla/firefox. Check both, and let FIREFOX_PROFILE_DIR override.
if [ -n "${FIREFOX_PROFILE_DIR:-}" ]; then
    base="$FIREFOX_PROFILE_DIR"
elif [ -f "$HOME/.config/mozilla/firefox/profiles.ini" ]; then
    base="$HOME/.config/mozilla/firefox"
elif [ -f "$HOME/.mozilla/firefox/profiles.ini" ]; then
    base="$HOME/.mozilla/firefox"
else
    echo "error: no profiles.ini found. Launch Firefox once to create a profile," >&2
    echo "       or set FIREFOX_PROFILE_DIR to the directory holding it." >&2
    exit 1
fi

ini="$base/profiles.ini"
[ -f "$ini" ] || { echo "error: $ini not found" >&2; exit 1; }

# ── Resolve which profile is active ──────────────────────────────────────────
# 1. The [Install…] section's Default= value (this is what Firefox itself uses).
# 2. Otherwise the profile flagged Default=1.
profile=""
profile=$(awk '/^\[Install/{in_install=1; next} /^\[/{in_install=0}
                in_install && /^Default=/{sub(/^Default=/,""); print; exit}' "$ini")
if [ -z "$profile" ]; then
    profile=$(awk '/^Default=1/{f=1; next} f && /^Path=/{sub(/^Path=/,""); print; exit} /^Path=/{p=$0} END{if(!found)print p}' "$ini")
fi
[ -n "$profile" ] || profile=$(basename "$(find "$base" -maxdepth 1 -type d -name '*.default-release' | head -1)")

[ -n "$profile" ] && [ -d "$base/$profile" ] || {
    echo "error: could not resolve an existing profile dir under $base" >&2
    echo "  profiles.ini said: '$profile'" >&2
    exit 1
}

dest="$base/$profile"
echo "==> Firefox profile: $dest"

if pgrep -x firefox >/dev/null 2>&1; then
    echo "    note: Firefox is running. The links are correct but the theme only"
    echo "          applies on next launch."
fi

# ── Link the theme files ─────────────────────────────────────────────────────
# The chrome/ SUBDIRECTORY is required. userChrome.css in the profile ROOT is
# silently ignored, despite what most guides say and despite the comment in
# libpref's all.js claiming "user profile directory". Verified against
# nsXREDirProvider.cpp, which appends "chrome" to NS_APP_USER_CHROME_DIR.
mkdir -p "$dest/chrome"

link() { # link <src> <dst>
    local src="$1" dst="$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "    skip (exists, not a symlink): $dst"
        return
    fi
    ln -sfn "$src" "$dst"
    echo "    $(basename "$dst")"
}

echo "==> Linking theme files into <profile>/chrome/"
link "$FIREFOX_DIR/userChrome.css"        "$dest/chrome/userChrome.css"
link "$FIREFOX_DIR/userContent.css"       "$dest/chrome/userContent.css"
link "$FIREFOX_DIR/fallback.css"          "$dest/chrome/fallback.css"
link "$FIREFOX_DIR/generated-colors.css"  "$dest/chrome/generated-colors.css"
link "$FIREFOX_DIR/user.js"               "$dest/user.js"

# ── Drop a stray content-override ────────────────────────────────────────────
# user.js already pins this to 2, which is what actually governs behaviour, but
# leaving a contradictory line in prefs.js is confusing to debug later.
prefs="$dest/prefs.js"
if [ -f "$prefs" ] && grep -q 'layout\.css\.prefers-color-scheme\.content-override' "$prefs"; then
    if pgrep -x firefox >/dev/null 2>&1; then
        echo "==> prefs.js has a content-override line, but Firefox is running."
        echo "    prefs.js is rewritten wholesale on exit, so editing it now is"
        echo "    pointless. user.js overrides it regardless. To tidy it up:"
        echo "      1. quit Firefox   2. re-run this script"
    else
        tmp=$(mktemp)
        grep -v 'layout\.css\.prefers-color-scheme\.content-override' "$prefs" > "$tmp"
        cat "$tmp" > "$prefs" && rm -f "$tmp"
        echo "==> Removed stray content-override from prefs.js"
    fi
fi

echo "==> Done. Restart Firefox to pick it up."
