# How it works

[Back to the README](../readme.md)

## How Zen loads the mod

- Zen loads mods from `chrome/zen-themes/<id>/` inside your profile and lists them in
  `zen-themes.json`. The installer puts the mod there and registers it.
- Zen applies every mod from one combined stylesheet, `chrome/zen-themes.css`, which it loads as it is
  when it starts. It only rebuilds that file when a mod or a mod setting changes inside Zen (up to Zen
  1.24.2b, also at startup when `zen.mods.last-update` was unset; Zen 1.24.3b dropped that). So the
  scripts rebuild it themselves whenever they add, update or remove this mod. They write the same file
  Zen would, with the `chrome.css` of every enabled mod in `zen-themes.json`, in its order, and Zen's
  next rebuild gives the same result.
- The mod's settings are preferences named `mod.cleanedurlbarext.*`. The scripts save the default of
  every setting that has none yet, as Zen does when it rebuilds, and Zen's settings page edits them. Text settings reach the CSS as variables, and every rule is
  wrapped in `@media -moz-pref(...)`, which is why an empty field means "Zen default".
- Before changing `prefs.js` or `zen-themes.json`, the scripts save a copy next to them ending in
  `.cleanedurlbarext.bak`. `uninstall.sh` deletes those copies once it has finished successfully.
- This mod is not in Zen's theme store, so Zen's automatic mod updates do not touch it; `update.sh`
  updates it.

## Fixes compared to the original

- **Blur works again** on Zen 1.19.9b and newer (Firefox 150+), which stopped `backdrop-filter` from
  seeing the page behind the URL bar. The fix (found by matteo-tafuro) is only applied while a blur is
  set.
- **Selectors updated** for current Zen: `.urlbar-background` (was `#urlbar-background`) and
  `[breakout-extend]` without a value (Zen 1.21.2b+), also from matteo-tafuro's fork.
- **The line between the text field and the results is removed again**: Firefox 158 (Zen 1.23.3b)
  moved it from `.urlbarView-body-inner`, where the original removed it, to `.urlbarView-results`;
  both are handled now.
- **Dark mode colours follow Zen's theme**: the custom colours use `light-dark()`, so they follow the
  theme chosen in Zen even when it differs from the system theme (`prefers-color-scheme` does not).
- **Icons on a selected result stay readable** with the subtle or transparent icon background (Zen
  paints them in a dark colour meant for its white tile).
- **No dependency on the mod's display name**: settings use `-moz-pref()` instead of the hidden
  element Zen names after the mod, and the Zen-only `-moz-bool-pref` is no longer needed.
- **The mod is there as soon as Zen starts** after installing or updating, instead of only after Zen
  happens to rebuild its mod stylesheet (Zen 1.24.3b and newer no longer rebuild it at startup).
