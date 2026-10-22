# Development

[Back to the README](../readme.md)

## Tests

```sh
tests/test_scripts.sh [bash] [awk]   # the scripts against fake Zen folders (try /bin/bash 3.2 and original-awk)
python3 tests/test_consistency.py    # preferences.json, catalogue, chrome.css and theme.json agree
python3 tests/fuzz_json_awk.py       # the awk JSON helper against Python's json module
```

## Behaviour questions

[`lib/catalogue.txt`](../lib/catalogue.txt) lists the behaviour questions `configure.sh` asks; its
header explains the line format.

- Every on/off or choice preference there must also be in `preferences.json`, so it shows in Zen's
  settings page. The consistency test checks it.
- A new question gets the next `since` revision, so `update.sh` offers it to existing users.
- When Zen renames a preference, keep the question under the new name and add
  `@renamed|<old>|<new>`, so saved values are moved.
- Update the tables in [Behaviour settings](behaviour-settings.md) to match.

## Releases

Raise `version` in [`theme.json`](../theme.json) for a release.
