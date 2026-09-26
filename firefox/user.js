// Firefox prefs for the wallpaper theme.
//
// Symlinked into <profile>/user.js by install.sh. user.js is applied on every
// startup and its values are written back into prefs.js, so anything set here
// is declarative and survives a Firefox update wiping the profile.
// This file is NEVER read in Safe Mode — that is an intentional Firefox
// behaviour (GlobalStyleSheetCache::InitFromProfile checks it), so a broken
// theme can always be escaped with `firefox -safe-mode`.

// ── The gate for userChrome.css / userContent.css ───────────────────────────
// Without this, both stylesheets are read from disk and silently discarded —
// no warning, no error. It still defaults to false in 156.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// ── Force dark ───────────────────────────────────────────────────────────────
// ui.systemUsesDarkTheme has NO default in 156 (it is absent from both all.js
// and StaticPrefList.yaml), so if it is not set the browser simply follows the
// desktop's colour scheme. Setting it explicitly is what keeps the theme dark
// regardless of the GTK setting.
user_pref("ui.systemUsesDarkTheme", 1);

// ── Restore the content colour scheme to "auto" ─────────────────────────────
// value 2 = Auto (follow the system / browser theme), 0 = always dark,
// 1 = always light.
//
// This is here to undo a stray `content-override = 0` that ended up in prefs.js
// during theming experiments: 0 forces EVERY website to render dark, ignoring
// its own styling, which is not what this theme wants — only the browser's own
// surfaces are themed. Declaring the default here is how you neutralise a pref
// declaratively, since user.js can override a value but cannot delete one.
user_pref("layout.css.prefers-color-scheme.content-override", 2);
