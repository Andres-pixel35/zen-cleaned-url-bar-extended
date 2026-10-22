#!/usr/bin/env bash
# Tests for install.sh, update.sh, uninstall.sh and configure.sh against fake
# Zen folders (no real Zen needed).
#
#   tests/test_scripts.sh [bash-to-test-with] [awk-to-test-with]
#
# The second argument lets the scripts run with another awk (for example
# original-awk, the BSD awk macOS is based on). Interactive questions are
# answered through `script`, which gives the scripts a terminal.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_BASH=${1:-bash}
TEST_AWK=${2:-}
PASS=0
FAIL=0
T=$(mktemp -d "${TMPDIR:-/tmp}/zcub-tests.XXXXXX")
trap 'rm -rf "$T"' EXIT

SHIM="$T/shim"
mkdir -p "$SHIM" "$T/tmp"
if [ -n "$TEST_AWK" ]; then
    case "$TEST_AWK" in
        "busybox awk") printf '#!/bin/sh\nexec busybox awk "$@"\n' >"$SHIM/awk" ;;
        *) printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v "$TEST_AWK")" >"$SHIM/awk" ;;
    esac
    chmod +x "$SHIM/awk"
fi
# No Zen process exists in the test world unless a test creates one.
printf '#!/bin/sh\nexit 1\n' >"$SHIM/pgrep"
chmod +x "$SHIM/pgrep"

pass() { PASS=$((PASS + 1)); }
fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n' "$*"
    [ -f "$T/out" ] && sed 's/^/    | /' "$T/out" | tail -25
}
check() { # check "description" command...
    local desc=$1
    shift
    if "$@"; then pass; else fail "$desc"; fi
}

new_home() {
    HOME_DIR="$T/home$((++HOME_N))"
    mkdir -p "$HOME_DIR"
}
HOME_N=0

# make_profile ROOT RELPATH [prefs lines...] -> creates a profile folder
make_profile() {
    local dir="$1/$2"
    shift 2
    mkdir -p "$dir"
    {
        echo '// Mozilla User Preferences'
        echo 'user_pref("zen.mods.last-update", 1792688010);'
        echo 'user_pref("browser.urlbar.suggest.searches", false);'
        printf '%s\n' "$@"
    } >"$dir/prefs.js"
    chmod 600 "$dir/prefs.js"
    echo '{}' >"$dir/times.json"
}

# run SCRIPT ARGS... (non-interactive: no terminal at all)
run() {
    local script=$1
    shift
    (cd "$T" && HOME=$HOME_DIR XDG_CONFIG_HOME="" PATH="$SHIM:$PATH" NO_COLOR=1 TMPDIR="$T/tmp" \
        "$TEST_BASH" "$ROOT/$script" "$@" </dev/null >"$T/out" 2>&1)
}

# run_tty "answers" SCRIPT ARGS... (answers fed to a terminal, one per line)
run_tty() {
    local answers=$1 script=$2 cmd
    shift 2
    cmd=$(printf '%q ' "$TEST_BASH" "$ROOT/$script" "$@")
    (cd "$T" && printf '%s' "$answers" | HOME=$HOME_DIR XDG_CONFIG_HOME="" PATH="$SHIM:$PATH" NO_COLOR=1 TMPDIR="$T/tmp" \
        script -qec "$cmd" /dev/null >"$T/out" 2>&1)
    sed -i 's/\r$//' "$T/out"
}

has_line() { grep -qxF "$2" "$1"; }
no_line() { ! grep -qF "$2" "$1"; }
out_has() { grep -qF -- "$1" "$T/out"; }
out_lacks() { ! grep -qF -- "$1" "$T/out"; }
json_ok() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null; }
json_eval() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }
mode_of() { ls -l "$1" | cut -c2-10; }


# ---------------------------------------------------------------- tests ----

test_bootstrap_blocks_identical() {
    local f first=""
    for f in install.sh update.sh uninstall.sh configure.sh; do
        sed -n '/^# ---- bootstrap/,/^# ---- end of bootstrap/p' "$ROOT/$f" >"$T/boot-$f"
        [ -s "$T/boot-$f" ] || { fail "bootstrap block missing in $f"; return; }
        if [ -z "$first" ]; then first=$f; continue; fi
        check "bootstrap block of $f matches $first" cmp -s "$T/boot-$first" "$T/boot-$f"
    done
}

test_install_legacy_root() {
    new_home
    local zen="$HOME_DIR/.zen" p
    make_profile "$zen" "Profiles/abc.Default (release)" 'user_pref("mod.cleanedurlbarext.panel.blur", "3px");'
    make_profile "$zen" "Profiles/old.Other"
    cat >"$zen/profiles.ini" <<'EOF'
[Profile1]
Name=Other
IsRelative=1
Path=Profiles/old.Other
Default=1

[Profile0]
Name=Default (release)
IsRelative=1
Path=Profiles/abc.Default (release)

[General]
StartWithLastProfile=1
Version=2

[Install4F96D1932A9F858E]
Default=Profiles/abc.Default (release)
Locked=1
EOF
    echo '{"other-mod":{"id":"other-mod","name":"Other","enabled":true}}' >"$zen/Profiles/abc.Default (release)/zen-themes.json"
    p="$zen/Profiles/abc.Default (release)"
    run install.sh --no-configure
    check "install (legacy ~/.zen) succeeds" [ $? -eq 0 ]
    check "install picks the [Install] default over Default=1" out_has "Using Zen profile \"Default (release)\""
    check "mod files copied" [ -f "$p/chrome/zen-themes/zen-cleaned-url-bar-extended/chrome.css" ]
    check "preferences.json copied" cmp -s "$ROOT/preferences.json" "$p/chrome/zen-themes/zen-cleaned-url-bar-extended/preferences.json"
    check "only the files Zen reads are installed" [ "$(ls "$p/chrome/zen-themes/zen-cleaned-url-bar-extended" | tr '\n' ' ')" = "chrome.css preferences.json " ]
    check "zen-themes.json valid" json_ok "$p/zen-themes.json"
    check "other mod kept" [ "$(json_eval "$p/zen-themes.json" 'd["other-mod"]["name"]')" = Other ]
    check "entry enabled" [ "$(json_eval "$p/zen-themes.json" 'd["zen-cleaned-url-bar-extended"]["enabled"]')" = True ]
    check "entry has preferences url" [ "$(json_eval "$p/zen-themes.json" 'd["zen-cleaned-url-bar-extended"]["preferences"].startswith("https://")')" = True ]
    check "user's own mod value kept" has_line "$p/prefs.js" 'user_pref("mod.cleanedurlbarext.panel.blur", "3px");'
    check "no option defaults written (Zen writes them)" [ "$(grep -c '^user_pref("mod\.cleanedurlbarext\.' "$p/prefs.js")" -eq 1 ]
    check "rebuild requested (last-update cleared)" no_line "$p/prefs.js" 'zen.mods.last-update'
    check "unrelated pref kept" has_line "$p/prefs.js" 'user_pref("browser.urlbar.suggest.searches", false);'
    check "prefs.js permissions kept" [ "$(mode_of "$p/prefs.js")" = "rw-------" ]
    check "prefs.js backup made" grep -q 'zen.mods.last-update' "$p/prefs.js.cleanedurlbarext.bak"
    check "zen-themes.json backup made" grep -q other-mod "$p/zen-themes.json.cleanedurlbarext.bak"
    check "other profile untouched" no_line "$zen/Profiles/old.Other/prefs.js" cleanedurlbarext

    # Reinstall keeps a disabled state and the user's values.
    python3 - "$p/zen-themes.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1])); d["zen-cleaned-url-bar-extended"]["enabled"] = False
json.dump(d, open(sys.argv[1], "w"), indent=2)
EOF
    run install.sh --no-configure
    check "reinstall succeeds" [ $? -eq 0 ]
    check "reinstall reports previous version" out_has "Reinstalled"
    check "reinstall keeps disabled mod disabled" [ "$(json_eval "$p/zen-themes.json" 'd["zen-cleaned-url-bar-extended"]["enabled"]')" = False ]
    check "reinstall keeps user value" has_line "$p/prefs.js" 'user_pref("mod.cleanedurlbarext.panel.blur", "3px");'
    check "no duplicate pref lines" [ "$(grep -c 'mod.cleanedurlbarext.panel.blur' "$p/prefs.js")" -eq 1 ]

    # update: nothing at all happens when the installed mod is current.
    rm -f "$p"/*.cleanedurlbarext.bak
    cp "$p/prefs.js" "$T/prefs-before"
    cp "$p/zen-themes.json" "$T/themes-before"
    run update.sh
    check "update succeeds when up to date" [ $? -eq 0 ]
    check "update says up to date" out_has "already up to date"
    check "up-to-date update leaves prefs.js alone" cmp -s "$T/prefs-before" "$p/prefs.js"
    check "up-to-date update leaves zen-themes.json alone" cmp -s "$T/themes-before" "$p/zen-themes.json"
    check "up-to-date update makes no backups" [ ! -e "$p/prefs.js.cleanedurlbarext.bak" ]

    # update: an older installed copy is replaced and Zen is asked to rebuild.
    m="$p/chrome/zen-themes/zen-cleaned-url-bar-extended"
    echo '/* old */' >>"$m/chrome.css"
    python3 - "$p/zen-themes.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1])); d["zen-cleaned-url-bar-extended"]["version"] = "0.9.0"
json.dump(d, open(sys.argv[1], "w"))
EOF
    echo 'user_pref("zen.mods.last-update", 1792688010);' >>"$p/prefs.js"
    run update.sh
    check "update succeeds" [ $? -eq 0 ]
    check "update reports the versions" out_has "0.9.0 -> "
    check "update replaces chrome.css" cmp -s "$ROOT/chrome.css" "$m/chrome.css"
    check "update writes the new version" [ "$(json_eval "$p/zen-themes.json" 'd["zen-cleaned-url-bar-extended"]["version"]')" = "$(json_eval "$ROOT/theme.json" 'd["version"]')" ]
    check "update keeps the mod disabled" [ "$(json_eval "$p/zen-themes.json" 'd["zen-cleaned-url-bar-extended"]["enabled"]')" = False ]
    check "update keeps other mods" [ "$(json_eval "$p/zen-themes.json" '"other-mod" in d')" = True ]
    check "update requests a rebuild" no_line "$p/prefs.js" 'zen.mods.last-update'
    check "update keeps user value" has_line "$p/prefs.js" 'user_pref("mod.cleanedurlbarext.panel.blur", "3px");'
    check "update adds no option defaults" [ "$(grep -c '^user_pref("mod\.cleanedurlbarext\.' "$p/prefs.js")" -eq 1 ]

    # update: changed files with the same version are refreshed too.
    echo '{}' >"$m/preferences.json"
    run update.sh
    check "same-version file change is refreshed" cmp -s "$ROOT/preferences.json" "$m/preferences.json"
    check "same-version refresh is reported" out_has "Updated the files"

    # uninstall keeps browser prefs unless --reset-prefs.
    echo 'user_pref("browser.urlbar.maxRichResults", 5);' >>"$p/prefs.js"
    run uninstall.sh
    check "uninstall without terminal needs -y" [ $? -ne 0 ]
    check "uninstall without -y changes nothing" [ -d "$p/chrome/zen-themes/zen-cleaned-url-bar-extended" ]
    run uninstall.sh -y
    check "uninstall succeeds" [ $? -eq 0 ]
    check "mod folder removed" [ ! -e "$p/chrome/zen-themes/zen-cleaned-url-bar-extended" ]
    check "entry removed" [ "$(json_eval "$p/zen-themes.json" '"zen-cleaned-url-bar-extended" in d')" = False ]
    check "other mod still there" [ "$(json_eval "$p/zen-themes.json" '"other-mod" in d')" = True ]
    check "mod prefs removed" no_line "$p/prefs.js" 'mod.cleanedurlbarext.'
    check "browser pref kept" has_line "$p/prefs.js" 'user_pref("browser.urlbar.maxRichResults", 5);'
    run uninstall.sh -y --reset-prefs
    check "reset-prefs succeeds when not installed" [ $? -eq 0 ]
    check "reset-prefs removes browser urlbar prefs" no_line "$p/prefs.js" 'browser.urlbar.maxRichResults'
    check "reset-prefs removes suggest.searches" no_line "$p/prefs.js" 'browser.urlbar.suggest.searches'
    check "reset-prefs lists what it reset" out_has "browser.urlbar.maxRichResults"
    run update.sh
    check "update refuses when not installed" [ $? -ne 0 ]
    check "update explains" out_has "not installed"
}

test_xdg_flatpak_and_ambiguity() {
    new_home
    local xdg="$HOME_DIR/.config/zen" flat="$HOME_DIR/.var/app/app.zen_browser.zen/.zen"
    make_profile "$xdg" "Profiles/x1.Default (release)"
    printf '[Profile0]\nName=Default (release)\nIsRelative=1\nPath=Profiles/x1.Default (release)\nDefault=1\n' >"$xdg/profiles.ini"
    printf '[AAAA]\nDefault=Profiles/x1.Default (release)\nLocked=1\n' >"$xdg/installs.ini"
    run install.sh --no-configure
    check "XDG root found" [ -f "$xdg/Profiles/x1.Default (release)/chrome/zen-themes/zen-cleaned-url-bar-extended/chrome.css" ]

    make_profile "$flat" "Profiles/f1.Default (release)"
    printf '[Profile0]\nName=Flatpak\nIsRelative=1\nPath=Profiles/f1.Default (release)\n\n[InstallBBBB]\nDefault=Profiles/f1.Default (release)\n' >"$flat/profiles.ini"
    run install.sh --no-configure
    check "two default profiles without a terminal fail" [ $? -ne 0 ]
    check "ambiguity lists both" out_has "$flat/Profiles/f1.Default (release)"
    check "ambiguity suggests -p" out_has "-p <folder>"

    run_tty $'2\nn\n' install.sh
    check "interactive choice works" [ -f "$flat/Profiles/f1.Default (release)/chrome/zen-themes/zen-cleaned-url-bar-extended/chrome.css" ]

    run install.sh --no-configure -p "$flat"
    check "-p with a Zen root folder selects inside it" [ $? -eq 0 ]
    run install.sh --no-configure -p "$HOME_DIR"
    check "-p with an unrelated folder fails" [ $? -ne 0 ]
    check "-p error mentions about:support" out_has "about:support"
    run install.sh --no-configure -p "$HOME_DIR/does-not-exist"
    check "-p with a missing folder fails" [ $? -ne 0 ]
}

test_absolute_profile_and_fresh_files() {
    new_home
    local zen="$HOME_DIR/.zen" abs="$T/elsewhere/My Profile"
    mkdir -p "$zen" "$T/elsewhere"
    mkdir -p "$abs"
    echo '{}' >"$abs/times.json"
    printf '[Profile0]\nName=Abs\nIsRelative=0\nPath=%s\nDefault=1\n' "$abs" >"$zen/profiles.ini"
    run install.sh --no-configure
    check "absolute profile path works" [ $? -eq 0 ]
    check "zen-themes.json created when missing" [ "$(json_eval "$abs/zen-themes.json" 'list(d)')" = "['zen-cleaned-url-bar-extended']" ]
    # A second profiles.ini listing the same profile must not make it ambiguous.
    mkdir -p "$HOME_DIR/.config/zen"
    printf '[Profile0]\nName=Same\nIsRelative=0\nPath=%s\nDefault=1\n' "$abs" >"$HOME_DIR/.config/zen/profiles.ini"
    run install.sh --no-configure
    check "same profile listed twice is not ambiguous" [ $? -eq 0 ]
}

test_macos_layout() {
    new_home
    local mac="$HOME_DIR/Library/Application Support/zen"
    make_profile "$mac" "Profiles/m1.Default (release)"
    printf '[Profile0]\nName=Default (release)\nIsRelative=1\nPath=Profiles/m1.Default (release)\n\n[Install1234]\nDefault=Profiles/m1.Default (release)\n' >"$mac/profiles.ini"
    printf '#!/bin/sh\necho Darwin\n' >"$SHIM/uname"
    chmod +x "$SHIM/uname"
    : >"$mac/Profiles/m1.Default (release)/.parentlock"
    run install.sh --no-configure
    check "macOS path with spaces works" [ -f "$mac/Profiles/m1.Default (release)/chrome/zen-themes/zen-cleaned-url-bar-extended/chrome.css" ]
    rm -f "$SHIM/uname"
}

test_invalid_themes_json() {
    new_home
    local zen="$HOME_DIR/.zen" p
    make_profile "$zen" "Profiles/a.b"
    printf '[Profile0]\nName=A\nIsRelative=1\nPath=Profiles/a.b\nDefault=1\n' >"$zen/profiles.ini"
    p="$zen/Profiles/a.b"
    echo '{"broken": ' >"$p/zen-themes.json"
    cp "$p/prefs.js" "$T/prefs-before"
    run install.sh --no-configure
    check "invalid zen-themes.json stops the install" [ $? -ne 0 ]
    check "error names the file" out_has "zen-themes.json is not valid JSON"
    check "broken file left as it was" [ "$(cat "$p/zen-themes.json")" = '{"broken": ' ]
    check "prefs.js untouched on failure" cmp -s "$T/prefs-before" "$p/prefs.js"
}

test_zen_running() {
    new_home
    local zen="$HOME_DIR/.zen" p fakezen pid
    make_profile "$zen" "Profiles/r.r"
    printf '[Profile0]\nName=R\nIsRelative=1\nPath=Profiles/r.r\nDefault=1\n' >"$zen/profiles.ini"
    p="$zen/Profiles/r.r"
    # A process called "zen" holding the profile lock.
    fakezen="$T/bin/zen"
    mkdir -p "$T/bin"
    cp "$(command -v sleep)" "$fakezen"
    "$fakezen" 30 &
    pid=$!
    ln -s "127.0.0.1:+$pid" "$p/lock"
    cp "$p/prefs.js" "$T/prefs-before"
    run install.sh --no-configure
    check "running Zen stops a non-interactive install" [ $? -ne 0 ]
    check "message says Zen is running" out_has "Zen is running"
    check "nothing changed while Zen runs" cmp -s "$T/prefs-before" "$p/prefs.js"
    check "no mod folder while Zen runs" [ ! -e "$p/chrome" ]
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    run install.sh --no-configure
    check "stale lock (no Zen process) does not block" [ $? -eq 0 ]

    "$fakezen" 30 &
    pid=$!
    ln -sf "127.0.0.1:+$pid" "$p/lock"
    run update.sh
    check "up-to-date update works while Zen runs" [ $? -eq 0 ]
    echo '/* old */' >>"$p/chrome/zen-themes/zen-cleaned-url-bar-extended/chrome.css"
    run update.sh
    check "a real update waits for Zen to be closed" [ $? -ne 0 ]
    check "update explains Zen is running" out_has "Zen is running"
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
}

test_configure() {
    new_home
    local zen="$HOME_DIR/.zen" p answers
    make_profile "$zen" "Profiles/c.c" 'user_pref("browser.urlbar.trimWww", true);' 'user_pref("zen.urlbar.behavior", "float");'
    printf '[Profile0]\nName=C\nIsRelative=1\nPath=Profiles/c.c\nDefault=1\n' >"$zen/profiles.ini"
    p="$zen/Profiles/c.c"

    run configure.sh --list
    check "--list works without a terminal" [ $? -eq 0 ]
    check "--list shows the choice label" out_has "Always float in the centre"
    check "--list marks defaults" out_has "(Zen default)"

    # Sections 1 and 4.
    answers=$'1 4\n'
    # Section 1: behaviour -> 1 (normal); replace-newtab -> n, so wait-to-clear is
    # skipped; open-on-startup keep; openintab -> y; the 4 remaining keep.
    answers+=$'1\nn\n\ny\n\n\n\n\n'
    # Section 4: history -> n; bookmark -> d; 17 x keep; maxRichResults -> 007.
    answers+=$'n\nd\n'
    answers+=$'\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'
    answers+=$'007\n'
    # Save.
    answers+=$'y\n'
    run_tty "$answers" configure.sh
    check "configure succeeds" grep -q "Saved" "$T/out"
    check "choice saved as string" has_line "$p/prefs.js" 'user_pref("zen.urlbar.behavior", "normal");'
    check "bool saved" has_line "$p/prefs.js" 'user_pref("zen.urlbar.replace-newtab", false);'
    check "dependent question skipped" out_has "Skipped"
    check "openintab saved" has_line "$p/prefs.js" 'user_pref("browser.urlbar.openintab", true);'
    check "history off saved" has_line "$p/prefs.js" 'user_pref("browser.urlbar.suggest.history", false);'
    check "int saved without leading zeros" has_line "$p/prefs.js" 'user_pref("browser.urlbar.maxRichResults", 7);'
    check "keep leaves other values" has_line "$p/prefs.js" 'user_pref("browser.urlbar.trimWww", true);'
    check "unanswered section untouched" has_line "$p/prefs.js" 'user_pref("browser.urlbar.suggest.searches", false);'
    check "summary printed" out_has "zen.urlbar.behavior: Always float in the centre -> Expand in place, never float"

    # Answering the default value removes the user value; q stops early; "d" resets.
    run_tty $'2\n\n\n\nd\nq\ny\n' configure.sh
    check "d resets to Zen default" no_line "$p/prefs.js" 'browser.urlbar.trimWww'
    check "q finishes and saves" grep -q "Saved" "$T/out"

    run_tty $'1\n2\nq\ny\n' configure.sh
    check "picking Zen's default value means no user value" no_line "$p/prefs.js" 'zen.urlbar.behavior'

    run_tty $'3\nq\n' configure.sh
    check "no answers -> nothing to change" out_has "Nothing to change"

    run_tty $'1\n3\nq\nn\n' configure.sh
    check "declining the summary saves nothing" out_has "Nothing was saved"
    check "declined change not written" no_line "$p/prefs.js" 'zen.urlbar.behavior'

    run_tty $'9\nx\n1\nbogus\n\nq\n' configure.sh
    check "bad section and bad answer are re-asked" [ "$(grep -c 'Please enter numbers from the list' "$T/out")" -ge 2 ] && out_has "not a valid answer"

    # user.js overriding a changed pref is reported.
    echo 'user_pref("zen.urlbar.behavior", "float");' >"$p/user.js"
    run_tty $'1\n1\nq\ny\n' configure.sh
    check "user.js override warned" out_has "user.js sets these preferences again"

    # install --configure goes straight into the questions.
    run_tty $'q\n' install.sh --configure
    check "install --configure asks the questions" out_has "Which parts?"
    check "install --configure does not ask whether to configure" out_lacks "Configure the URL bar behaviour now?"

    # Without a flag install asks; yes runs the questions right away.
    run_tty $'y\n1\n3\nq\ny\n' install.sh
    check "install asks whether to configure" out_has "Configure the URL bar behaviour now?"
    check "answering yes configures right away" has_line "$p/prefs.js" 'user_pref("zen.urlbar.behavior", "float");'
    run_tty $'n\n' install.sh
    check "answering no skips the questions" out_lacks "Which parts?"
    run_tty '' install.sh --no-configure
    check "--no-configure neither asks nor configures" out_lacks "Configure the URL bar"
}

test_nothing_left_behind() {
    local left
    left=$(ls -A "$T/tmp")
    check "no temporary files left by any script run" [ -z "$left" ]
    [ -z "$left" ] || printf '    left: %s\n' "$left"
}

test_pref_string_escaping() {
    (
        ROOT_DIR=$ROOT
        # shellcheck source=../lib/common.sh
        . "$ROOT/lib/common.sh"
        PREFS_JS="$T/escape-prefs.js"
        USER_JS=/dev/null
        : >"$PREFS_JS"
        pref_set "a.b" "$(pref_string 'say "hi" \ there')"
        prefs_apply
        raw=$(pref_get "$PREFS_JS" a.b)
        [ "$raw" = '"say \"hi\" \\ there"' ] && [ "$(pref_display "$raw")" = 'say "hi" \ there' ]
    )
    check "prefs.js string escaping round trip" [ $? -eq 0 ]
}

# ----------------------------------------------------------------- main ----

for t in test_bootstrap_blocks_identical test_install_legacy_root test_xdg_flatpak_and_ambiguity \
    test_absolute_profile_and_fresh_files test_macos_layout test_invalid_themes_json test_zen_running \
    test_configure test_pref_string_escaping test_nothing_left_behind; do
    $t
done

printf '%s: %d passed, %d failed (bash: %s, awk: %s)\n' "$(basename "$0")" "$PASS" "$FAIL" \
    "$("$TEST_BASH" -c 'echo $BASH_VERSION')" "${TEST_AWK:-default}"
[ "$FAIL" -eq 0 ]
