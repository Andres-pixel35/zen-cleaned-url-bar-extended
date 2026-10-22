# Behaviour settings

[Back to the README](../readme.md)

The URL bar's behaviour comes from Zen's own preferences, the ones you could also edit in
`about:config`. There are two ways to change them:

- **Zen's mod settings page** (**Settings > Zen Mods > Cleaned URL Bar Extended**, below the look
  options) has the on/off and choice preferences. These are the ones marked **Yes** in the "In mod
  settings" column below.
- **`configure.sh`** asks about all of them, one question at a time, including the numbers the
  settings page cannot edit:

  ```sh
  curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/configure.sh | bash
  ```

  To only see the current values, add `-s -- --list` after `bash`. For its other options, see
  [Install, update and uninstall](install.md#the-scripts-at-a-glance).

These are normal Zen preferences: they stay when the mod is disabled or removed, unless you uninstall
with `--reset-prefs`. The "Zen default" column shows Zen 1.23's default.

> [!NOTE]
> - Some preferences only matter together, and `configure.sh` skips the questions that do not apply.
>   For example, search suggestions need `browser.search.suggest.enabled`, which Zen turns off by
>   default. The table notes these as "Only asked when...".
> - Hiding or showing the search-engine buttons row (`zen.urlbar.hide-one-offs`) takes effect after
>   restarting Zen.
> - Zen locks a few URL bar preferences (sponsored "quick suggest" results and top-site suggestions)
>   and turns off the services behind others (trending searches, weather, Firefox Suggest), so they
>   are not offered here.
> - Some preferences do not exist in older Zen versions, so changing them does nothing there. See
>   [Requirements](requirements.md#zen-browser).

## Sections

- [Opening and behaviour](#opening-and-behaviour)
- [Address display](#address-display)
- [Buttons and icons](#buttons-and-icons)
- [Suggestions](#suggestions)
- [Search](#search)
- [Advanced](#advanced)

## Opening and behaviour

How the URL bar opens, where results open and how it reacts to focus.

| Question | Preference | Zen default | In mod settings |
|---|---|---|---|
| How should the URL bar open?<br><sub>Floating = it pops up in the centre of the window, like a command palette.</sub> | `zen.urlbar.behavior` | Float when opened with the keyboard (Ctrl+L, Ctrl+T), expand in place when clicked | Yes |
| Open the URL bar instead of a blank page when you open a new tab?<br><sub>With this on, Ctrl+T or the new-tab button shows the URL bar and only creates a tab once you pick something.</sub> | `zen.urlbar.replace-newtab` | on | Yes |
| How long, in milliseconds, should Zen remember what you typed in a new-tab URL bar you dismissed?<br><sub>Reopening the new-tab URL bar within this time restores your text. 45000 = 45 seconds, 0 = forget immediately. Only asked when `zen.urlbar.replace-newtab` is on.</sub> | `zen.urlbar.wait-to-clear` | `45000` | No |
| Open the URL bar automatically when Zen starts on an empty tab? | `zen.urlbar.open-on-startup` | on | Yes |
| Open what you pick in the URL bar in a new tab instead of the current one? | `browser.urlbar.openintab` | off | Yes |
| When a "Switch to tab" result belongs to another window, move that tab into the current window?<br><sub>Off = Zen jumps to the other window instead.</sub> | `browser.urlbar.switchTabs.adoptIntoActiveWindow` | off | Yes |
| Let Shift, Alt or Ctrl change what the selected result does?<br><sub>Example: holding Shift on a "Switch to tab" result visits the page in the current tab instead of switching.</sub> | `zen.urlbar.enable-overrides` | off | Yes |
| Close the URL bar dropdown when the Zen window loses focus? | `browser.urlbar.closeOnWindowBlur` | off | Yes |
| Move focus back to the page when you press Esc in an empty URL bar? | `browser.urlbar.focusContentDocumentOnEsc` | on | Yes |

## Address display

How the address of the current page is shown.

| Question | Preference | Zen default | In mod settings |
|---|---|---|---|
| In the single-toolbar layout, show only the domain (example.com) instead of the full address?<br><sub>When this is on, the trimming questions below only affect the full address shown while editing.</sub> | `zen.urlbar.show-domain-only-in-sidebar` | on | Yes |
| Hide "http://" and trailing slashes in addresses? | `browser.urlbar.trimURLs` | on | Yes |
| Also hide "https://"? | `browser.urlbar.trimHttps` | on | Yes |
| Hide a leading "www."? | `browser.urlbar.trimWww` | off | Yes |
| Show the full address (with https://) as soon as you click into the URL bar? | `browser.urlbar.untrimOnUserInteraction.featureGate` | on | Yes |
| Copy addresses in readable form (for example a space instead of %20)? | `browser.urlbar.decodeURLsOnCopy` | off | Yes |

## Buttons and icons

Buttons Zen itself can show or hide in the URL bar (the mod adds more icon options in Zen Settings > Mods).

| Question | Preference | Zen default | In mod settings |
|---|---|---|---|
| Show the tracking-protection shield icon? | `zen.urlbar.show-protections-icon` | off | Yes |
| Show the Picture-in-Picture button when a page plays video? | `zen.urlbar.show-pip-button` | off | Yes |
| Show the container label when a tab is in a container? | `zen.urlbar.show-contextual-id` | off | Yes |
| Show the "Copy URL" button in the single-toolbar layout? | `zen.urlbar.single-toolbar-show-copy-url` | on | Yes |
| Show the Share button? | `browser.urlbar.share-button.enabled` | off | Yes |
| Use Zen's own frosted-glass background for the open URL bar?<br><sub>The mod's "Panel: Background" setting replaces it unless that setting is left on "Zen default".</sub> | `zen.theme.acrylic-urlbar` | off | Yes |

## Suggestions

Which kinds of results appear in the dropdown.

| Question | Preference | Zen default | In mod settings |
|---|---|---|---|
| Suggest pages from your browsing history? | `browser.urlbar.suggest.history` | on | Yes |
| Suggest bookmarks? | `browser.urlbar.suggest.bookmark` | on | Yes |
| Suggest tabs you already have open ("Switch to tab")? | `browser.urlbar.suggest.openpage` | on | Yes |
| Suggest tabs open on your other synced devices?<br><sub>Needs Zen Sync with tabs syncing enabled.</sub> | `browser.urlbar.suggest.remotetab` | on | Yes |
| When the URL bar is empty, include your pinned shortcuts?<br><sub>The empty URL bar shows your top sites; this controls the pinned ones among them.</sub> | `zen.urlbar.show-pinned` | on | Yes |
| When the URL bar is empty, include sponsored shortcuts? | `zen.urlbar.show-sponsored` | off | Yes |
| Suggest search engines whose name or keyword matches what you type (tab-to-search)? | `browser.urlbar.suggest.engines` | on | Yes |
| Suggest the link you just copied? | `browser.urlbar.suggest.clipboard` | on | Yes |
| Show a calculator result when you type a math expression? | `browser.urlbar.suggest.calculator` | on | Yes |
| Show unit conversions (for example "10 km to mi")? | `browser.urlbar.unitConversion.enabled` | on | Yes |
| Suggest your recent searches when the URL bar is empty? | `browser.urlbar.suggest.recentsearches` | on | Yes |
| How many recent searches should be shown at most?<br><sub>Only asked when `browser.urlbar.suggest.recentsearches` is on.</sub> | `browser.urlbar.recentsearches.maxResults` | `5` | No |
| Enable Firefox quick actions (for example "Settings", "Clear history", "Downloads")? | `browser.urlbar.quickactions.enabled` | on | Yes |
| Show quick actions among normal results?<br><sub>Off = they only appear when you type "> " to enter quick-action mode. Only asked when `browser.urlbar.quickactions.enabled` is on.</sub> | `browser.urlbar.suggest.quickactions` | on | Yes |
| Suggest Zen commands (for example "Toggle compact mode", "New split view")? | `zen.urlbar.suggestions.quick-actions` | on | Yes |
| Offer to search the current site when it has its own search engine? | `browser.urlbar.contextualSearch.enabled` | on | Yes |
| Autocomplete addresses inline as you type? | `browser.urlbar.autoFill` | on | Yes |
| Show group headings above kinds of results? | `browser.urlbar.groupLabels.enabled` | off | Yes |
| Merge history results that only differ by their #anchor? | `browser.urlbar.deduplication.enabled` | on | Yes |
| How many results should the dropdown show at most?<br><sub>The mod's "Results: List height before scrolling" setting controls how many fit before scrolling.</sub> | `browser.urlbar.maxRichResults` | `10` | No |

## Search

What happens with text that is not an address, and search-engine suggestions.

| Question | Preference | Zen default | In mod settings |
|---|---|---|---|
| Search with your default engine when what you type is not an address?<br><sub>Off = everything you type is treated as an address.</sub> | `keyword.enabled` | on | Yes |
| Ask your search engine for suggestions as you type?<br><sub>This sends what you type to the search engine. It is the master switch for the next questions.</sub> | `browser.search.suggest.enabled` | off | Yes |
| Show those search suggestions in the URL bar?<br><sub>Only asked when `browser.search.suggest.enabled` is on.</sub> | `browser.urlbar.suggest.searches` | on | Yes |
| Show search suggestions above history and bookmarks?<br><sub>Only asked when `browser.search.suggest.enabled` is on.</sub> | `browser.urlbar.showSearchSuggestionsFirst` | on | Yes |
| Also show search suggestions in private windows?<br><sub>Only asked when `browser.search.suggest.enabled` is on.</sub> | `browser.search.suggest.enabled.private` | off | Yes |
| Show "tail" suggestions that complete only the end of a long query?<br><sub>Only asked when `browser.search.suggest.enabled` is on.</sub> | `browser.urlbar.richSuggestions.tail` | on | Yes |
| Remember search and form history?<br><sub>Needed to suggest your past searches. Note: this also makes Zen remember what you type in web forms.</sub> | `browser.formfill.enable` | off | Yes |
| How many of your past searches should be suggested at most?<br><sub>Only asked when `browser.formfill.enable` is on.</sub> | `browser.urlbar.maxHistoricalSearchSuggestions` | `2` | No |
| Hide the row of search-engine buttons at the bottom of the dropdown?<br><sub>Takes effect after restarting Zen.</sub> | `zen.urlbar.hide-one-offs` | on | Yes |
| Show a "search bookmarks" button in that row?<br><sub>Only asked when `zen.urlbar.hide-one-offs` is off.</sub> | `browser.urlbar.shortcuts.bookmarks` | on | Yes |
| Show a "search tabs" button in that row?<br><sub>Only asked when `zen.urlbar.hide-one-offs` is off.</sub> | `browser.urlbar.shortcuts.tabs` | on | Yes |
| Show a "search history" button in that row?<br><sub>Only asked when `zen.urlbar.hide-one-offs` is off.</sub> | `browser.urlbar.shortcuts.history` | on | Yes |
| Show a "search workspaces" button in that row?<br><sub>Only asked when `zen.urlbar.hide-one-offs` is off.</sub> | `browser.urlbar.shortcuts.workspaces` | on | Yes |
| Treat a single word (like "router") as a local host name before searching for it? | `browser.fixup.dns_first_for_single_words` | off | Yes |
| After you search a single word, check if it is also a local host and offer "Did you mean to go to ..."? | `browser.urlbar.dnsResolveSingleWordsAfterSearch` | Never | No |

## Advanced

Performance and keyboard details.

| Question | Preference | Zen default | In mod settings |
|---|---|---|---|
| Pre-connect to the likely destination while you type?<br><sub>Faster loading, but Zen contacts the site before you press Enter.</sub> | `browser.urlbar.speculativeConnect.enabled` | on | Yes |
| Make Ctrl+Enter turn "example" into "www.example.com"? | `browser.urlbar.ctrlCanonizesURLs` | on | Yes |
| How long, in milliseconds, to wait after you stop typing before updating results? | `browser.urlbar.delay` | `50` | No |
