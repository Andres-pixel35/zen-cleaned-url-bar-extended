# Requirements

[Back to the README](../readme.md)

## Zen Browser

**Zen 1.16b or newer** (Firefox 143 or newer) on Linux or macOS. **Every** look setting and behaviour
question works on **Zen 1.24.3b or newer**.

On older versions some of Zen's buttons and preferences do not exist yet, so the settings for them do
nothing; everything else works:

| Zen version | Look settings | Behaviour preferences with no effect (they do not exist yet) |
|---|---|---|
| 1.15.5b and older | **Not supported**: before Firefox 143 the URL bar's background element has another name | - |
| 1.16b | All except hiding the site data, split view and copy URL buttons (Zen does not have them yet) | `zen.urlbar.open-on-startup`, `zen.urlbar.show-pip-button`, `zen.urlbar.show-contextual-id`, `zen.urlbar.single-toolbar-show-copy-url`, `browser.urlbar.closeOnWindowBlur`, `browser.urlbar.trimWww`, `browser.urlbar.share-button.enabled`, `browser.urlbar.shortcuts.workspaces`, `zen.theme.acrylic-urlbar`, `zen.urlbar.show-pinned`, `zen.urlbar.show-sponsored`, `zen.urlbar.single-toolbar-show-zoom-button` |
| 1.17b | All except hiding the split view button | The same as 1.16b, except `zen.urlbar.show-contextual-id`, which works |
| 1.18b, 1.19.9b, 1.21b | All | `zen.urlbar.single-toolbar-show-zoom-button`; in 1.19.9b also `browser.urlbar.trimWww`, `browser.urlbar.share-button.enabled`, `browser.urlbar.shortcuts.workspaces`, `zen.theme.acrylic-urlbar`, `zen.urlbar.show-pinned`, `zen.urlbar.show-sponsored` |
| 1.22b, 1.23b | All | `zen.theme.acrylic-urlbar` (added in 1.23.1b), `zen.urlbar.show-pinned` and `zen.urlbar.show-sponsored` (added in 1.23.3b), `zen.urlbar.single-toolbar-show-zoom-button` (added in 1.24.3b) |
| 1.23.3b, 1.23.4b, 1.24b, 1.24.1b, 1.24.2b | All | `zen.urlbar.single-toolbar-show-zoom-button` |
| 1.24.3b | All | None |

A version between two rows works at least as well as the row above it: Zen and Firefox only added
these buttons and preferences over time, never removed them.

<details>
<summary>How this was checked</summary>

On the Linux builds of Zen 1.15.5b, 1.16b, 1.17b, 1.18b, 1.19.9b, 1.21b, 1.22b, 1.23b and 1.23.4b,
`install.sh` was run on a fresh profile, Zen was started (it applied the mod by itself), and every
look setting was set and read back from the real URL bar; the blur was also checked on screen.

Which preferences exist was read from the 1.16b, 1.17b, 1.19.9b, 1.22b, 1.23b and 1.23.4b builds. The
versions that added `zen.theme.acrylic-urlbar`, `zen.urlbar.show-pinned` and
`zen.urlbar.show-sponsored` come from Zen's source code.

On 1.24b, 1.24.1b and 1.24.2b, `install.sh` was run the same way, and every look setting was set and
checked automatically in the real URL bar: open in place, floating and at rest. Each behaviour
preference's existence, type and default were read from the running Zen, and Zen's code was checked to
still use it. `configure.sh`, `update.sh` and `uninstall.sh` were run against 1.24.1b, and
`configure.sh` against 1.24.2b, with the results read back from Zen.

Zen 1.24.3b stopped rebuilding its mod stylesheet at startup, so the scripts now build it themselves
(see [How it works](how-it-works.md)). With that change, `install.sh` was run on fresh profiles of
1.16b, 1.23.4b, 1.24.2b and 1.24.3b, and the mod was applied as soon as Zen started. On 1.23.4b,
1.24.2b and 1.24.3b every look setting was then checked again; on 1.24.3b every behaviour preference
too, and `update.sh` and `uninstall.sh` were run. The stylesheet the scripts write was compared with
the one Zen writes itself, with other mods installed (one of them turned off): they match except for
the time stamp.

</details>

> [!CAUTION]
> Zen versions newer than 1.24.3b were not available to test. Zen changes its URL bar now and then,
> so a future version may need an update of this mod.

## Tools used by the scripts

Nothing to install on macOS or on a normal Linux desktop: everything below comes with the system.
No jq, Python, Node or root access is needed, and nothing is installed system-wide. The mod itself
needs nothing: Zen loads it with its own mod system.

| Tool | Linux package | Used for |
|---|---|---|
| `bash` 3.2 or newer (macOS's built-in bash works) | `bash` | Running the scripts |
| `curl` | `curl` | Downloading the project (only when run with `curl ... \| bash`) |
| `tar` and `gzip` | `tar`, `gzip` | Unpacking that download |
| `awk` (any: gawk, mawk, busybox or BSD awk) | `gawk` or `mawk` | Reading `profiles.ini`, `zen-themes.json` and `prefs.js` |
| `sed`, `grep` | `sed`, `grep` | Small text edits and checks |
| `cat`, `cp`, `mv`, `rm`, `mkdir`, `mktemp`, `chmod`, `ls`, `tr`, `dirname`, `readlink`, `uname` | `coreutils` | File handling |
| `pgrep` (or `ps`) | `procps` / `procps-ng` | Telling whether Zen is running |
| `lsof` (macOS only, built in) | - | Telling whether Zen is running on macOS |

On Windows, [install by hand](install.md#install-by-hand-windows).
