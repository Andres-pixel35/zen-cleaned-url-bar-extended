# Install, update and uninstall

[Back to the README](../readme.md)

- [The scripts at a glance](#the-scripts-at-a-glance)
- [Install](#install)
- [Choosing the profile](#choosing-the-profile)
- [Why Zen must be closed](#why-zen-must-be-closed)
- [Update](#update)
- [Uninstall](#uninstall)
- [What is kept on your computer](#what-is-kept-on-your-computer)
- [Install by hand (Windows)](#install-by-hand-windows)

## The scripts at a glance

The scripts are for Linux and macOS. Run them with `curl ... | bash` as shown in the README, or clone
the repository and run them directly (`./install.sh`, `./update.sh`...). To pass options through
`curl ... | bash`, add `-s --` before them:

```sh
curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/install.sh | bash -s -- --no-configure
```

| Script | What it does | Its own options |
|---|---|---|
| `install.sh` | Installs the mod, or reinstalls it keeping your settings, then offers the behaviour questions | `--configure` goes straight to the questions; `--no-configure` skips them |
| `configure.sh` | Asks about the URL bar's behaviour preferences and saves your answers. Works with or without the mod installed | `-l`, `--list` only shows the current values and changes nothing |
| `update.sh` | Updates the mod and the behaviour settings, only where something changed | - |
| `uninstall.sh` | Removes the mod, its settings and its backups, after asking you to confirm | `--reset-prefs` also puts the URL bar preferences back to Zen's defaults; `-y`, `--yes` does not ask for confirmation |

Every script also accepts:

- `-p`, `--profile <folder>`: the Zen profile to use (see [Choosing the profile](#choosing-the-profile)).
- `--ref <branch or tag>`: use the scripts and files from another branch or tag of the repository.
- `-h`, `--help`: show the help.

> [!NOTE]
> With `curl ... | bash`, nothing the script downloads stays on your computer: the project goes to a
> temporary folder that is deleted when the script ends, also when it fails or you cancel it.
> `configure.sh` is never stored either, so its questions are always the latest.

## Install

`install.sh`:

1. Finds your Zen profile (see [Choosing the profile](#choosing-the-profile)) and waits until Zen is
   closed.
2. Copies `chrome.css` and `preferences.json` into the profile's
   `chrome/zen-themes/zen-cleaned-url-bar-extended/` folder and registers the mod in
   `zen-themes.json`. Settings you already had are kept.
3. Makes Zen rebuild its mod stylesheet at the next start, so the mod shows up a moment after Zen
   starts (see [How it works](how-it-works.md)).
4. Asks whether you also want to set the URL bar's behaviour. If you answer yes, it runs the
   `configure.sh` questions right away.

## Choosing the profile

Without `-p`, the scripts use the profile Zen opens by default. They only ask you to choose when that
is ambiguous, for example when both Zen and Zen Twilight are installed. They look for Zen in:

| System | Folders |
|---|---|
| Linux | `~/.zen` and `~/.config/zen` (or `$XDG_CONFIG_HOME/zen`) |
| Linux, Flatpak | `~/.var/app/app.zen_browser.zen/.zen` and `~/.var/app/app.zen_browser.zen/config/zen` |
| macOS | `~/Library/Application Support/zen` |

To choose the profile yourself, pass its folder with `-p`. You find it in Zen at `about:support` >
**Profile Directory**:

```sh
curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/install.sh | bash -s -- -p "/path/to/your/profile"
```

`-p` also accepts a Zen folder that contains `profiles.ini` (for example `~/.zen`); the scripts then
choose among the profiles listed there.

## Why Zen must be closed

Zen rewrites its settings files when it quits, which would undo the scripts' changes. So
whenever a script is about to write something and Zen is open, it asks you to close Zen and waits.
When a script has nothing to change, Zen may stay open.

## Update

The mod is not in Zen's theme store, so Zen's automatic mod updates do not touch it. `update.sh`
keeps both parts up to date and changes only what is new:

- **The look**: it compares the installed `chrome.css` and `preferences.json` with the latest ones
  and replaces them only when they differ.
- **The behaviour settings** saved by `configure.sh`:
  - If Zen renamed one of those preferences, your value is moved to the new name. A value you already
    saved under the new name is kept.
  - If questions were added since you last answered them, it lists them and offers to ask just those.
    Without a terminal it tells you to run `configure.sh`.

When everything is up to date it changes nothing.

## Uninstall

`uninstall.sh` asks for confirmation (skip it with `-y`), then removes:

- the mod's folder and its entry in `zen-themes.json`;
- the mod's own settings (`mod.cleanedurlbarext.*`);
- the backups the scripts made (`*.cleanedurlbarext.bak`), once everything else succeeded.

The URL bar preferences you changed (floating mode, suggestions...) are normal Zen preferences, so
they are kept. To put them back to Zen's defaults too, pass `--reset-prefs`.

## What is kept on your computer

Only what Zen uses, all inside your Zen profile:

| File | What it is |
|---|---|
| `chrome/zen-themes/zen-cleaned-url-bar-extended/chrome.css` and `preferences.json` | The look of the URL bar and the list of its settings |
| The mod's entry in `zen-themes.json` | Zen's list of installed mods |
| Your settings, in `prefs.js` | The mod's own (`mod.cleanedurlbarext.*`) and any URL bar preference you changed. One of the mod's, `mod.cleanedurlbarext.questions-seen`, is just a number: the latest set of behaviour questions you were asked, so `update.sh` knows which ones are new |
| `prefs.js.cleanedurlbarext.bak` and `zen-themes.json.cleanedurlbarext.bak` | A copy of those two files from before the last change a script made, in case you need to undo it |

There is only ever one backup of each file (every run replaces it), so they take about as much space
as the files themselves: usually a few tens of KB for `prefs.js` and around 1 KB for
`zen-themes.json`.

## Install by hand (Windows)

The scripts do not run on Windows. There (or to do it yourself anywhere):

1. In Zen, open `about:support` and open the **Profile Directory**. Close Zen.
2. Inside the profile, create the folder `chrome/zen-themes/zen-cleaned-url-bar-extended` and copy
   [`chrome.css`](../chrome.css) and [`preferences.json`](../preferences.json) from this repository
   into it.
3. Open `zen-themes.json` in the profile (create it with `{}` if it does not exist). Add the content of
   [`theme.json`](../theme.json) as a new entry with the key `"zen-cleaned-url-bar-extended"` and an
   extra `"enabled": true`.
4. Start Zen, open `about:config`, delete `zen.mods.last-update` and restart Zen. Zen rebuilds its
   mod stylesheet at the next start when that preference is missing. (Changing any setting of any mod
   in **Settings > Zen Mods** also rebuilds it, without a restart.)
