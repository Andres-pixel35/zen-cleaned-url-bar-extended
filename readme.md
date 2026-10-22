<div align="center">

# Cleaned URL Bar Extended

A clean, glassy URL bar for [Zen Browser](https://zen-browser.app/) where you can personalise both
its look and its behaviour.

[![Zen 1.16b or newer](https://img.shields.io/badge/Zen-1.16b%2B-blue?style=flat-square)](docs/requirements.md)
[![Linux and macOS](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-555?style=flat-square)](#install)
[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fandres-pixel35%2Fzen-cleaned-url-bar-extended%2Fmain%2Ftheme.json&query=%24.version&label=version&style=flat-square)](theme.json)
[![MIT License](https://img.shields.io/badge/license-MIT-yellow?style=flat-square)](LICENSE)

![The open URL bar with the default settings](docs/preview.webp)

</div>

> [!NOTE]
> This started as a fork of [Zen Cleaned URL Bar](https://github.com/dinnoyow/zen-cleaned-url-bar),
> which is no longer maintained, and builds on the fixes of
> [Better Cleaned URL Bar](https://github.com/matteo-tafuro/zen-better-cleaned-url-bar). See [Credits](#credits).

## Features

- **Every part of the look is a setting**: background colour, transparency and blur, corners,
  border, shadow, fonts, text sizes and colours, row height, which icons show... 46 options in Zen's
  mod settings, applied instantly.
- **Leave a field empty to keep Zen's style**, so you only change what you care about.
- **The behaviour too**: floating or in place, which suggestions appear, how many results, how
  addresses are shown, including options that otherwise only exist in `about:config`.
- **Custom colours follow Zen's light and dark theme**, even when it differs from your system's.
- **Works on current Zen**: the blur, the selectors and the hidden separator line are fixed for
  recent versions ([what was fixed](docs/how-it-works.md#fixes-compared-to-the-original)).
- **One-line install and update** that keep your settings and leave nothing behind but what Zen uses.

## Install

> [!IMPORTANT]
> Needs **Zen 1.16b or newer** on **Linux or macOS** (1.23.3b or newer for every option to work).
> The scripts only use tools that come with the system. See [Requirements](docs/requirements.md).

1. Close Zen.
2. Run in a terminal:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/install.sh | bash
   ```

3. The script installs the mod into the profile Zen opens by default, keeping any settings you
   already had. It then asks whether you want to set the URL bar's [behaviour](#behaviour) now;
   you can also do it later.
4. Start Zen. The new URL bar appears a moment after startup.

> [!WARNING]
> If you use the original Cleaned URL Bar or Better Cleaned URL Bar, remove or disable it in
> **Settings > Zen Mods**: they style the same elements and would conflict. Their settings are not
> reused; this mod has its own.

To pick another profile, run it from a clone, or install on Windows by hand, see
[Install, update and uninstall](docs/install.md).

## Customise

### Look

Open **Settings > Zen Mods > Cleaned URL Bar Extended**. Every change applies instantly.

![The mod's settings in Zen](docs/settings.png)

- A field that shows **Zen default** keeps Zen's own style while it is empty.
- **Colours** are any CSS colour: `#ff8800`, `rgb(255 136 0)`, `hsl(32 100% 50%)` or a name like
  `orange`. Add an opacity for a see-through colour: `rgb(255 136 0 / 50%)`.
- **Sizes** are a number with a unit: `12px`, or `1.2em` (relative to the text size).

> [!TIP]
> If something looks wrong after a change, check the value: an invalid one does not fall back to
> Zen's style, that part resets to a plain default instead (for example no border at all). Empty the
> field to get Zen's style back.

Every look setting, what it expects and its default: [Look settings](docs/look-settings.md).

### Behaviour

The behaviour comes from Zen's own URL bar preferences, the ones in `about:config`. You can change
them in two ways:

- **In Zen**: the on/off and choice preferences are in the same mod settings page, below the look
  options.
- **With `configure.sh`**: it asks about every preference, one question at a time, including the
  numbers the settings page cannot edit (how many results, delays...):

  ```sh
  curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/configure.sh | bash
  ```

These are normal Zen preferences, so they stay if you remove the mod (unless you uninstall with
`--reset-prefs`). Every preference and its default: [Behaviour settings](docs/behaviour-settings.md).

## Update and uninstall

Close Zen first: if it is open, the script asks you to close it and waits.

| To | Run |
|---|---|
| Update, keeping your settings | `curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/update.sh \| bash` |
| Show the current behaviour settings | `curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/configure.sh \| bash -s -- --list` |
| Uninstall | `curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/uninstall.sh \| bash` |
| Uninstall and put the URL bar preferences back to Zen's defaults | `curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/uninstall.sh \| bash -s -- --reset-prefs` |

This mod is not in Zen's theme store, so Zen does not update it on its own: run `update.sh`. It only
changes what is new and also offers the behaviour questions added since you last answered them.
What each script does, its options and what stays on your computer:
[Install, update and uninstall](docs/install.md).

## Documentation

| Page | What is in it |
|---|---|
| [Install, update and uninstall](docs/install.md) | Choosing a profile, script options, what each script changes, what is kept on your computer, installing by hand (Windows) |
| [Look settings](docs/look-settings.md) | All 46 look settings, the values they accept and their defaults |
| [Behaviour settings](docs/behaviour-settings.md) | All 59 behaviour preferences `configure.sh` asks about, their Zen defaults and which are in Zen's settings page |
| [Requirements](docs/requirements.md) | Which Zen versions support which options, and the tools the scripts use |
| [How it works](docs/how-it-works.md) | How Zen loads the mod and what was fixed compared to the original |
| [Development](docs/development.md) | Running the tests and adding behaviour questions |

## Credits

- [DinnoDEV / dinnoyow](https://github.com/dinnoyow/zen-cleaned-url-bar): the original Zen Cleaned URL
  Bar, its design and options.
- [KennethThomson](https://github.com/KennethThomson): light and dark mode colours in the original
  (dinnoyow/zen-cleaned-url-bar#14).
- [matteo-tafuro](https://github.com/matteo-tafuro/zen-better-cleaned-url-bar): Better Cleaned URL
  Bar, which restored the blur and the selectors on recent Zen versions and added the accent colour
  modes, blur amount, selected-result opacity, dimmed URLs, favicon background and smooth transitions
  that this mod keeps.
