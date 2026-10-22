# Look settings

[Back to the README](../readme.md)

All look settings are in **Settings > Zen Mods > Cleaned URL Bar Extended** and apply instantly. They
are grouped by the part of the URL bar they change:

- [Panel](#panel): the URL bar while it is open, expanded in place or floating.
- [Results](#results): the rows in the open URL bar.
- [Selected result](#selected-result): the highlighted row.
- [Resting bar](#resting-bar): the URL bar when it is not focused, in the sidebar or the top toolbar.
- [Icons](#icons): the buttons and icons inside the URL bar.
- [Search buttons row](#search-buttons-row): the row of search-engine buttons under the results.

## Values

- **Empty**: a text field that shows **Zen default** keeps Zen's own style while it is empty, so you
  only change what you want. In the tables below, "empty" means the field is empty by default.
- **A CSS colour** can be written as hex (`#ff8800`), `rgb(255 136 0)`, `hsl(32 100% 50%)` or a name
  (`orange`, `white`). For a see-through colour add the opacity: `rgb(255 136 0 / 50%)` or
  `#ff880080`.
- **A size** is a number with a unit: `12px` (pixels) or `1.2em` (relative to the text size). Some
  settings also take `%`, as noted.
- **A CSS border** is a width, a style and a colour, for example `2px solid #808080` or
  `1px dashed rgb(255 255 255 / 30%)`. `none` removes it.
- **A font** is the name of a font installed on your computer, for example `Inter` or
  `JetBrains Mono`. Several, separated by commas, are tried in order (`JetBrains Mono, monospace`).
  `sans-serif`, `serif` and `monospace` also work.

> [!WARNING]
> A value that is not valid CSS does **not** fall back to Zen's style: that part resets to a plain
> default instead (for example no border at all, or plain black or white text). If something looks
> wrong, check the value, or empty the field to get Zen's style back.

## Panel

| Setting | What to enter | Default |
|---|---|---|
| Background | **Zen accent colour**, **Custom colours** (the two colour settings below) or **Zen default** (Zen's own background) | Zen accent colour |
| Background transparency | A percentage: `0%` solid, `100%` invisible. Used with the accent and custom colours | `90%` |
| Custom colour, dark theme | A CSS colour, e.g. `#1a1a1a`. Used when Background is Custom and Zen's theme is dark | `hsl(0 0 10)` |
| Custom colour, light theme | A CSS colour, e.g. `#e6e6e6`. Used when Background is Custom and Zen's theme is light | `hsl(0 0 90)` |
| Background blur | A size, e.g. `25px`. `0px` or empty = no blur | `25px` |
| Corner radius | A size, e.g. `15px`. `0px` = square corners | `15px` |
| Border | A CSS border, e.g. `2px solid #808080`. `none` = no border | `3px solid hsl(0 0 50 / 10%)` |
| Remove the drop shadow | On or off | off |
| Remove the line between the text field and the results | On or off | on |
| Width when floating | A percentage of the window, e.g. `60%`, or pixels, e.g. `800px`. Only while the bar floats | empty |
| Distance from the top when floating | A percentage of the window height, e.g. `20%`, or pixels, e.g. `150px`. Only while the bar floats | empty |
| Font | A font, e.g. `Inter` | empty |
| Typed text size | A size, e.g. `18px` or `1.2em` | empty |
| Typed text colour | A CSS colour, e.g. `#ffffff` | empty |

## Results

| Setting | What to enter | Default |
|---|---|---|
| Row corner radius | A size, e.g. `11px`. `0px` = square rows | `11px` |
| Fade the highlight in and out smoothly | On or off | on |
| Row height | A size, e.g. `38px`. Zen uses `45px`; smaller makes the list compact | empty |
| List height before scrolling | A size, e.g. `400px`, or `none` for no limit. Zen uses `244px` (about five rows) | empty |
| Text size | A size, e.g. `13px` or `0.9em`. Zen uses `14px` | empty |
| Title colour | A CSS colour for the page titles of the rows that are not selected, e.g. `#e0e0e0` | empty |
| Address colour | A CSS colour for the addresses of the rows that are not selected, e.g. `#9a9a9a` | empty |
| Hover background | A CSS colour for the row under the mouse; a see-through one works best, e.g. `rgb(255 255 255 / 10%)` | empty |
| Dim addresses to make titles stand out | On or off | on |
| Hide addresses, show titles only | On or off | off |

## Selected result

| Setting | What to enter | Default |
|---|---|---|
| Background | **Zen accent colour (softened)**, **Custom colour** (the setting below) or **Zen default** | Zen accent colour (softened) |
| Background transparency | A percentage: `0%` solid, `100%` invisible | `70%` |
| Custom background colour | A CSS colour, e.g. `#5050fa`. Used when Background is Custom | `hsl(0 0 80)` |
| Text colour | A CSS colour for the text of the selected row, e.g. `#ffffff`. Works with any background | empty |
| Icon background | **Subtle tint**, **None** or **Zen default** (a white tile) | Subtle tint |

## Resting bar

| Setting | What to enter | Default |
|---|---|---|
| Background colour | A CSS colour, e.g. `rgb(255 255 255 / 8%)` | empty |
| Corner radius | A size, e.g. `10px` | empty |
| Border | A CSS border, e.g. `1px solid #808080` | empty |
| Font | A font, e.g. `Inter` | empty |
| Text size | A size, e.g. `14px` or `1em` | empty |
| Text colour | A CSS colour, e.g. `#cccccc` | empty |
| Centre the address | On or off | off |

## Icons

All on or off.

| Setting | Default |
|---|---|
| Hide the site information (lock) icon | off |
| Hide Zen's site data / extensions button | off |
| Hide granted-permission icons | off |
| Show the reader view button (when available) | off |
| Show the bookmark star | off |
| Hide the zoom level indicator | off |
| Hide the translations button | off |
| Hide the split view button | off |
| Hide the copy URL button | off |

Some of these buttons do not exist in older Zen versions, so hiding them does nothing there. See
[Requirements](requirements.md#zen-browser).

## Search buttons row

| Setting | What to enter | Default |
|---|---|---|
| Rounded, borderless style | On or off. The row only shows when Zen's "hide the search-engine buttons row" preference (`zen.urlbar.hide-one-offs`) is off | on |

Below the look settings, the same page also has the URL bar's behaviour preferences. They are
described in [Behaviour settings](behaviour-settings.md).
